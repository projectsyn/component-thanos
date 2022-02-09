local alerts = import 'alerts.libsonnet';
local thanosMixin = import 'github.com/thanos-io/thanos/mixin/mixin.libsonnet';
local thanos = import 'kube-thanos/thanos.libsonnet';
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local inv = kap.inventory();
local params = inv.parameters.thanos;

local store = thanos.store(params.commonConfig + params.store) {
  alerts: alerts.PrometheusRuleFromMixin('thanos-store-alerts', [ 'thanos-store', 'thanos-store.rules' ], params.store_alerts),

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
