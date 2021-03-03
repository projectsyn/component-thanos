local thanosMixin = import 'github.com/thanos-io/thanos/mixin/mixin.libsonnet';
local thanos = import 'kube-thanos/thanos.libsonnet';
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local inv = kap.inventory();
local params = inv.parameters.thanos;

local compactor = thanos.compact(params.commonConfig + params.compactor) {
  statefulSet+: {
    spec+: {
      template+: {
        spec+: {
          securityContext+: {
            runAsUser: 10001,
          },
        },
      },
    },
  },
  alerts+: kube._Object('monitoring.coreos.com/v1', 'PrometheusRule', 'thanos-compactor-alerts') {
    metadata+: {
      namespace: params.namespace,
    },
    spec+: {
      groups+:
        std.filter(
          function(group) group.name == 'thanos-compact.rules',
          thanosMixin.prometheusAlerts.groups
        ),
    },
  },
};

if params.compactor.enabled then {
  ['compactor/' + name]: compactor[name]
  for name in std.objectFields(compactor)
} else {}
