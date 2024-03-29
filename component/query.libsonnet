local alerts = import 'alerts.libsonnet';
local thanosMixin = import 'github.com/thanos-io/thanos/mixin/mixin.libsonnet';
local thanos = import 'kube-thanos/thanos.libsonnet';
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local inv = kap.inventory();
local params = inv.parameters.thanos;
local instance = inv.parameters._instance;

local extraStores = std.filter(
  function(it) it != null,
  [
    if params.store.enabled then
      'dnssrv+_grpc._tcp.thanos-store.%s.svc.cluster.local' % params.namespace,
    if params.receive.enabled then
      'dnssrv+_grpc._tcp.thanos-receive.%s.svc.cluster.local' % params.namespace,
  ]
);

local proxyImage = params.images.oauthProxy;
local proxyServicePort = 8080;

// Ensure we don't inherit any stores configured by kube-thanos by making sure
// we overwrite the kube-thanos defaults value of the `stores` key before
// merging our config over it.
local queryBaseConfig = { stores: [] };

local query = thanos.query(queryBaseConfig + params.commonConfig + params.query {
  // Configure the stores that should be enabled to make the querier work
  // with the other components deployed through this component.
  stores+: extraStores,
}) {
  alerts: alerts.PrometheusRuleFromMixin('thanos-query-alerts', [ 'thanos-query', 'thanos-query.rules' ], params.query_alerts),
  custom_alerts: alerts.PrometheusRuleForCustom('thanos-query-custom-alerts', 'thanos-query-custom.rules', params.query_alerts.custom),

  service+: {
    spec+: {
      type: params.query.serviceType,
    },
  },
  serviceAccount+: {
    metadata+: {
      annotations+: if params.queryRbacProxy.enabled then {
        'serviceaccounts.openshift.io/oauth-redirecturi.primary': 'https://' + params.queryRbacProxy.ingress.host,
        // there is also another annotation:
        //  serviceaccounts.openshift.io/oauth-redirectreference.primary: '{"kind":"OAuthRedirectReference","apiVersion":"v1","reference":{"kind":"Route","name":"<route-name>"}}'
        // However, using an Ingress object generates a randomized Route name, and setting `kind: Ingress` didn't work.
        // So we have to give an static URL.
      },
    },
  },
  deployment+: {
    spec+: {
      template+: {
        local pod = self,
        spec+: {
          containers+: if params.queryRbacProxy.enabled then [
            {
              assert std.startsWith(inv.parameters.facts.distribution, 'openshift') : 'RBAC proxy is only supported on OpenShift distributions',

              name: 'openshift-oauth-proxy',
              image: '%s/%s:%s' % [ proxyImage.registry, proxyImage.image, proxyImage.tag ],
              args: [
                '--upstream=http://0.0.0.0:9090',
                '--provider=openshift',
                '--cookie-secret-file=/var/run/secrets/kubernetes.io/serviceaccount/token',
                '--openshift-service-account=%s' % pod.spec.serviceAccountName,
                // TODO: Replace JSON below with `std.manifestJsonMinified({...}})` once available in newer jsonnet version
                // Only cluster-admins should be able to get system resources
                '--openshift-sar={"namespace":"%s","resource":"services","name":"%s-auth","verb":"get"}' % [ params.namespace, instance ],
                '--http-address=http://:%s' % proxyServicePort,
                '--https-address=',
              ],
              ports: [
                {
                  containerPort: proxyServicePort,
                  name: 'proxy',
                },
              ],
            },
          ] else [],
        },
      },
    },
  },
};

// This Service is intended to be between Ingress and the proxy sidecar of the Querier.
local proxyService = kube.Service('%s-auth' % instance) {
  metadata+: {
    labels+: query.deployment.metadata.labels,
  },
  spec+: {
    ports: [
      {
        name: 'proxy',
        port: proxyServicePort,
        targetPort: proxyServicePort,
      },
    ],
  },
  target_pod: query.deployment.spec.template,
};

local ingress = params.queryRbacProxy.ingress;
local proxyIngress = if ingress.enabled then kube.Ingress(instance) {
  assert std.length(ingress.host) > 0 : 'queryRbacProxy.ingress.host in %s (component-thanos) cannot be empty' % instance,

  apiVersion: 'networking.k8s.io/v1',  // kube.Ingress creates version with 'v1beta1'
  metadata+: {
    annotations: if ingress.annotations != null then ingress.annotations else {},
    labels+: query.deployment.metadata.labels + params.queryRbacProxy.ingress.labels,
  },
  spec+: {
    rules+: [
      {
        host: ingress.host,
        http: {
          paths: [
            {
              path: '/',
              pathType: 'Prefix',
              backend: {
                service: {
                  name: proxyService.metadata.name,
                  port: {
                    number: proxyServicePort,
                  },
                },
              },
            },
          ],
        },
      },
    ],
    tls+: [
      {
        hosts: [ ingress.host ],
        secretName: '%s-tls' % instance,
      },
    ],
  },
} else {};

local queryArtifacts = if params.query.enabled then {
  [if !alerts.IgnoreManifest(query[name]) then 'query/' + name]:
    query[name]
  for name in std.objectFields(query)
} else {};

{
  [if params.query.enabled && params.queryRbacProxy.enabled then '50_auth-proxy']: [ proxyService, proxyIngress ],
} + queryArtifacts
