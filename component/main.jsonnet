local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local inv = kap.inventory();
local params = inv.parameters.thanos;

local configureObjStore = std.objectHas(params.objectStorageConfig, 'type');


{
  '00_namespace': kube.Namespace(params.namespace),
  [if configureObjStore then '40_thanos_objstore']: kube.Secret(params.commonConfig.objectStorageConfig.name) {
    metadata+: {
      namespace: params.namespace,
    },
    stringData: {
      [params.commonConfig.objectStorageConfig.key]: std.manifestYamlDoc(params.objectStorageConfig),
    },
  },
}
+ (import 'query.libsonnet')
+ (import 'store.libsonnet')
+ (import 'dashboards.libsonnet')
