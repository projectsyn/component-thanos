local thanosMixin = import 'github.com/thanos-io/thanos/mixin/mixin.libsonnet';
local thanos = import 'kube-thanos/thanos.libsonnet';
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local inv = kap.inventory();
local params = inv.parameters.thanos;

local alertlabels = {
  syn: 'true',
  syn_component: 'thanos',
};

local coalesce = function(a, b) if a != null then a else b;

local rulePatch = function(alertConfig, rule)
  local patches = coalesce(alertConfig.patches, {});
  com.makeMergeable(com.getValueOrDefault(patches, '*', {}))
  + com.makeMergeable(com.getValueOrDefault(patches, rule.alert, {}));

local ruleEnabled = function(alertConfig, rule)
  (std.objectHas(alertConfig.enabled, '*') && alertConfig.enabled['*'] == true)
  || (std.objectHas(alertConfig.enabled, rule.alert) && alertConfig.enabled[rule.alert] == true);

local fromMixin =
  function(name, mixinGroupNames, alertConfig) kube._Object('monitoring.coreos.com/v1', 'PrometheusRule', name) {
    metadata+: {
      namespace: params.namespace,
    },
    spec+: {
      groups+:
        std.filterMap(
          function(group) std.member(mixinGroupNames, group.name),
          function(group) group {
            rules:
              std.filterMap(
                function(rule) ruleEnabled(alertConfig, rule),
                function(rule) rule {
                  labels+: alertlabels,
                } + rulePatch(alertConfig, rule),
                super.rules
              ),
          },
          thanosMixin.prometheusAlerts.groups
        ),
    },
  };

{
  PrometheusRuleFromMixin: fromMixin,
}
