local thanosMixin = import 'github.com/thanos-io/thanos/mixin/mixin.libsonnet';
local thanos = import 'kube-thanos/thanos.libsonnet';
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local inv = kap.inventory();
local params = inv.parameters.thanos;

local extraStores = std.filter(
  function(it) it != null,
  [
    if params.store.enabled then
      'dnssrv+_grpc._tcp.thanos-store.%s.svc.cluster.local' % params.namespace,
    if params.receive.enabled then
      'dnssrv+_grpc._tcp.thanos-receive.%s.svc.cluster.local' % params.namespace,
  ]
);

local proxyImage = params.images.kubeRbacProxy;
local proxyContainer = {
  name: 'kube-rbac-proxy',
  image: '%s/%s:%s' % [ proxyImage.registry, proxyImage.image, proxyImage.tag ],
  args: [
    '--upstream=http://0.0.0.0:9090',
    '--insecure-listen-address=0.0.0.0:%s' % params.queryRbacProxy.port,
    '--secure-listen-address=0.0.0.0:8443',
    '--logtostderr=true',
    '--v=2',
  ],
  ports: [
    {
      containerPort: params.queryRbacProxy.port,
      name: 'proxy',
    },
    {
      containerPort: 8443,
      name: 'secure-proxy',
    },
  ],
};

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
  deployment+: {
    spec+: {
      template+: {
        spec+: {
          containers+: if params.queryRbacProxy.enabled then [ proxyContainer ] else [],
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

// This Role grants the RBAC proxy to review access on behalf of the client.
local proxyRole = kube.Role(params.queryRbacProxy.serviceName) {
  rules+: [
    {
      apiGroups: [ 'authentication.k8s.io' ],
      resources: [ 'tokenreviews' ],
      verbs: [ 'create' ],
    },
    {
      apiGroups: [ 'authorization.k8s.io' ],
      resources: [ 'subjectaccessreviews' ],
      verbs: [ 'create' ],
    },
  ],
};

// This RoleBinding binds the Querier SA to the previous role
local proxyRoleBinding = kube.RoleBinding(params.queryRbacProxy.serviceName) {
  roleRef: {
    apiGroup: 'rbac.authorization.k8s.io',
    kind: 'Role',
    name: proxyRole.metadata.name,
  },
  subjects+: [
    {
      kind: 'ServiceAccount',
      name: query.serviceAccount.metadata.name,
      namespace: query.serviceAccount.metadata.namespace,
    },
  ],
};

local queryArtifacts = if params.query.enabled then {
  ['query/' + name]: query[name]
  for name in std.objectFields(query)
} else {};

{
  [if params.query.enabled && params.queryRbacProxy.enabled then '51_auth-proxy']: [ proxyService, proxyRole, proxyRoleBinding ],
} + queryArtifacts
