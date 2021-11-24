local thanosMixin = import 'github.com/thanos-io/thanos/mixin/mixin.libsonnet';
local thanos = import 'kube-thanos/thanos.libsonnet';
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local inv = kap.inventory();
local params = inv.parameters.thanos;

local query = thanos.query(params.commonConfig + params.query {
  [if params.store.enabled then 'stores']+: [ 'dnssrv+_grpc._tcp.thanos-store.%s.svc.cluster.local' % params.namespace ],
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
