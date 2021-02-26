local thanosMixin = import 'github.com/thanos-io/thanos/mixin/mixin.libsonnet';
local thanos = import 'kube-thanos/thanos.libsonnet';
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local inv = kap.inventory();
local params = inv.parameters.thanos;

if params.dashboards.enabled then {
  ['dashboards/' + std.rstripChars(name, '.json')]:
    kube.ConfigMap('dashboard-thanos-' + std.rstripChars(name, '.json')) {
      metadata+: {
        namespace: params.dashboards.namespace,
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
} else {}
