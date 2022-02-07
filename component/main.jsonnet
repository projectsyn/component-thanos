local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local inv = kap.inventory();
local params = inv.parameters.thanos;

local configureObjStore = std.objectHas(params.objectStorageConfig, 'type');

local monitoringLabel =
  if std.startsWith(inv.parameters.facts.distribution, 'openshift') then
    {
      'openshift.io/cluster-monitoring': 'true',
    }
  else
    {
      SYNMonitoring: 'main',
    };

{
  [if params.createNamespace then '00_namespace']: kube.Namespace(params.namespace) {
    metadata+: {
      labels+: monitoringLabel,
    },
  },
  [if configureObjStore then '40_thanos_objstore']: kube.Secret(params.commonConfig.objectStorageConfig.name) {
    metadata+: {
      namespace: params.namespace,
    },
    stringData: {
      [params.commonConfig.objectStorageConfig.key]: std.manifestYamlDoc(params.objectStorageConfig),
    },
  },
}
+ (import 'bucket.libsonnet')
+ (import 'compactor.libsonnet')
+ (import 'dashboards.libsonnet')
+ (import 'receive.libsonnet')
+ (import 'query.libsonnet')
+ (import 'store.libsonnet')
