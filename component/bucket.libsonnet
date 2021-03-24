local thanosMixin = import 'github.com/thanos-io/thanos/mixin/mixin.libsonnet';
local thanos = import 'kube-thanos/thanos.libsonnet';
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local inv = kap.inventory();
local params = inv.parameters.thanos;

local bucket = thanos.bucket(params.commonConfig + params.bucket);

if params.bucket.enabled then {
  ['bucket/' + name]: bucket[name]
  for name in std.objectFields(bucket)
} else {}
