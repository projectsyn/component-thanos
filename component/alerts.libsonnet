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
  local globalEnabled =
    std.get(alertConfig.enabled, '*', false) == true;

  (std.get(std.get(rule, 'labels', {}), 'severity', '') != 'info')
  // enable rule if either globally enabled and not explicitly disabled, or if
  // explicitly enabled.
  && std.get(alertConfig.enabled, rule.alert, globalEnabled) == true;

local customAlerts = function(name, groupName, customAlerts)
  com.namespaced(params.namespace, kube._Object('monitoring.coreos.com/v1', 'PrometheusRule', name) {
    spec+: {
      groups+: [
        {
          name: groupName,
          rules:
            std.sort(std.filterMap(
              function(field) customAlerts[field].enabled == true,
              function(field) customAlerts[field].rule {
                alert: field,
                labels+: alertlabels,
              },
              std.objectFields(customAlerts)
            )),
        },
      ],
    },
  });

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

local ignoreManifest(obj) =
  obj != null &&
  obj.kind == 'PrometheusRule' &&
  (
    obj.spec.groups == null ||
    obj.spec.groups[0].rules == null ||
    std.length(obj.spec.groups[0].rules) == 0
  );

{
  PrometheusRuleFromMixin: fromMixin,
  PrometheusRuleForCustom: customAlerts,
  IgnoreManifest: ignoreManifest,
}
