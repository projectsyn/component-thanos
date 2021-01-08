local thanosMixin = import 'github.com/thanos-io/thanos/mixin/mixin.libsonnet';
local thanos = import 'kube-thanos/thanos.libsonnet';
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local inv = kap.inventory();
local params = inv.parameters.thanos;

local query = thanos.query(params.commonConfig + params.query) {
  deployment+: {
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
  alerts+: kube._Object('monitoring.coreos.com/v1', 'PrometheusRule', 'thanos-alerts') {
    metadata+: {
      namespace: params.namespace,
    },
    spec+: {
      groups+:
        std.filter(
          function(group) group.name == 'thanos-query.rules',
          thanosMixin.prometheusAlerts.groups
        ),
    },
  },
};

{
  '00_namespace': kube.Namespace(params.namespace),
} +
{
  ['query/' + name]: query[name]
  for name in std.objectFields(query)
} +
{
  ['dashboards/' + std.rstripChars(name, '.json')]:
    kube.ConfigMap('dashboard-thanos-' + std.rstripChars(name, '.json')) {
      metadata+: {
        namespace: params.dashboardNamespace,
        labels+: {
          grafana_dashboard: '1',
        },
      },
      data+: {
        ['thanos-' + name]: std.manifestJson(thanosMixin.grafanaDashboards[name]),
      },
    }
  for name in std.objectFields(thanosMixin.grafanaDashboards)
  if std.member([ 'overview.json', 'query.json' ], name)
}
