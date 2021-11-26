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
};

if params.query.enabled then {
  ['query/' + name]: query[name]
  for name in std.objectFields(query)
} else {}
