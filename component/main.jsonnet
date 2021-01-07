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
};

{
  '00_namespace': kube.Namespace(params.namespace),
} +
{ ['query/' + name]: query[name] for name in std.objectFields(query) }
