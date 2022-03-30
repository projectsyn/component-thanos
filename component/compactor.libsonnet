local alerts = import 'alerts.libsonnet';
local thanosMixin = import 'github.com/thanos-io/thanos/mixin/mixin.libsonnet';
local thanos = import 'kube-thanos/thanos.libsonnet';
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local inv = kap.inventory();
local params = inv.parameters.thanos;

local compactor = thanos.compact(params.commonConfig + params.compactor) {
  alerts: alerts.PrometheusRuleFromMixin('thanos-compactor-alerts', [ 'thanos-compact.rules', 'thanos-compact' ], params.compactor_alerts),
  custom_alerts: alerts.PrometheusRuleForCustom('thanos-compactor-custom-alerts', 'thanos-compactor-custom.rules', params.compactor_alerts.custom),
};

if params.compactor.enabled then {
  [if !alerts.IgnoreManifest(compactor[name]) then 'compactor/' + name]:
    compactor[name]
  for name in std.objectFields(compactor)
} else {}
