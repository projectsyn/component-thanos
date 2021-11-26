local thanosMixin = import 'github.com/thanos-io/thanos/mixin/mixin.libsonnet';
local thanos = import 'kube-thanos/thanos.libsonnet';
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local inv = kap.inventory();
local params = inv.parameters.thanos;

local receiver = thanos.receive(params.commonConfig + params.receive) {
  alerts+: kube._Object('monitoring.coreos.com/v1', 'PrometheusRule', 'thanos-receiver-alerts') {
    metadata+: {
      namespace: params.namespace,
    },
    spec+: {
      groups+:
        std.filter(
          function(group) group.name == 'thanos-receive',
          thanosMixin.prometheusAlerts.groups
        ),
    },
  },
};

if params.receive.enabled then {
  ['receiver/' + name]: receiver[name]
  for name in std.objectFields(receiver)
} else {}
