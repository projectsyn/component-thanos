local alerts = import 'alerts.libsonnet';
local thanosMixin = import 'github.com/thanos-io/thanos/mixin/mixin.libsonnet';
local thanos = import 'kube-thanos/thanos.libsonnet';
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local inv = kap.inventory();
local params = inv.parameters.thanos;

local tstore = thanos.store(params.commonConfig + params.store) {
  alerts: alerts.PrometheusRuleFromMixin('thanos-store-alerts', [ 'thanos-store', 'thanos-store.rules' ], params.store_alerts),
  custom_alerts: alerts.PrometheusRuleForCustom('thanos-store-custom-alerts', 'thanos-store-custom.rules', params.store_alerts.custom),

  service+: {
    spec+: {
      type: params.store.serviceType,
    },
  },
};

local store = tstore {
  statefulSet+: {
    spec+: {
      template+: {
        spec+: {
          containers: [
            tstore.statefulSet.spec.template.spec.containers[0] {
              args+: params.store.additionalArgs,
            },
          ],
        },
      },
    },
  },
};

if params.store.enabled then {
  [if !alerts.IgnoreManifest(store[name]) then 'store/' + name]:
    store[name]
  for name in std.objectFields(store)
} else {}
