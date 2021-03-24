local thanosMixin = import 'github.com/thanos-io/thanos/mixin/mixin.libsonnet';
local thanos = import 'kube-thanos/thanos.libsonnet';
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local inv = kap.inventory();
local params = inv.parameters.thanos;

local store = thanos.store(params.commonConfig + params.store) {
  alerts+: kube._Object('monitoring.coreos.com/v1', 'PrometheusRule', 'thanos-store-alerts') {
    metadata+: {
      namespace: params.namespace,
    },
    spec+: {
      groups+:
        std.filter(
          function(group) group.name == 'thanos-store',
          thanosMixin.prometheusAlerts.groups
        ),
    },
  },
  service+: {
    spec+: {
      type: params.store.serviceType,
    },
  },
};

if params.store.enabled then {
  ['store/' + name]: store[name]
  for name in std.objectFields(store)
} else {}
