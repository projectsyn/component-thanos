local thanosMixin = import 'github.com/thanos-io/thanos/mixin/mixin.libsonnet';
local thanos = import 'kube-thanos/thanos.libsonnet';
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local inv = kap.inventory();
local params = inv.parameters.thanos;

{
  '00_namespace': kube.Namespace(params.namespace),
}
+ (import 'query.libsonnet')
+ if params.dashboards.enabled then
  (import 'dashboards.libsonnet') else {}
