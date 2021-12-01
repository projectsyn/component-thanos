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

// Ensure we don't inherit any stores configured by kube-thanos by making sure
// we overwrite the kube-thanos defaults value of the `stores` key before
// merging our config over it.
local queryBaseConfig = { stores: [] };

local query = thanos.query(queryBaseConfig + params.commonConfig + params.query {
  // Configure the stores that should be enabled to make the querier work
  // with the other components deployed through this component.
  stores+: extraStores,
}) {
  alerts+: kube._Object('monitoring.coreos.com/v1', 'PrometheusRule', 'thanos-query-alerts') {
    metadata+: {
      namespace: params.namespace,
    },
    spec+: {
      groups+:
        std.filter(
          function(group) group.name == 'thanos-query',
          thanosMixin.prometheusAlerts.groups
        ),
    },
  },
  service+: {
    spec+: {
      type: params.query.serviceType,
    },
  },
  serviceAccount+: {
    metadata+: {
      annotations+: if params.queryRbacProxy.enabled then {
        'serviceaccounts.openshift.io/oauth-redirecturi.primary': params.queryRbacProxy.redirectUri,
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
                '--openshift-service-account=%s' % 'thanos-query',
                // TODO: Replace JSON below with `std.manifestJsonMinified({...}})` once available in newer jsonnet version
                // Only cluster-admins should be able to get system resources
                '--openshift-sar={"namespace":"%s","resource":"services","name":"%s","verb":"get"}' % [ params.namespace, params.queryRbacProxy.serviceName ],
                '--http-address=http://:%s' % params.queryRbacProxy.port,
                '--https-address=',
              ],
              ports: [
                {
                  containerPort: params.queryRbacProxy.port,
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
local proxyService = kube.Service(params.queryRbacProxy.serviceName) {
  spec+: {
    ports: [
      {
        name: 'proxy',
        port: params.queryRbacProxy.port,
        targetPort: params.queryRbacProxy.port,
      },
    ],
  },
  target_pod: query.deployment.spec.template,
};

local queryArtifacts = if params.query.enabled then {
  ['query/' + name]: query[name]
  for name in std.objectFields(query)
} else {};

{
  [if params.query.enabled && params.queryRbacProxy.enabled then '51_auth-proxy']: [ proxyService ],
} + queryArtifacts
