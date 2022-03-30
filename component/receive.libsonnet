local alerts = import 'alerts.libsonnet';
local thanosMixin = import 'github.com/thanos-io/thanos/mixin/mixin.libsonnet';
local thanos = import 'kube-thanos/thanos.libsonnet';
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local inv = kap.inventory();
local params = inv.parameters.thanos;

local receiver = thanos.receive(params.commonConfig + params.receive) {
  alerts: alerts.PrometheusRuleFromMixin('thanos-receiver-alerts', [ 'thanos-receive', 'thanos-receive.rules' ], params.receive_alerts),
  custom_alerts: alerts.PrometheusRuleForCustom('thanos-receive-custom-alerts', 'thanos-receive-custom.rules', params.receive_alerts.custom),
};

if params.receive.enabled then {
  [if !alerts.IgnoreManifest(receiver[name]) then 'receiver/' + name]:
    receiver[name]
  for name in std.objectFields(receiver)
} else {}
