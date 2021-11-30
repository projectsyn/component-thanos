local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local inv = kap.inventory();
local params = inv.parameters.thanos;
local instance = inv.parameters._instance;

local ingress = kube.Ingress('%s' % instance) {
  assert std.length(params.ingress.host) > 0 : 'ingress.host in %s (component-thanos) cannot be empty' % instance,

  apiVersion: 'networking.k8s.io/v1',  // kube.Ingress creates version with 'v1beta1'
  metadata+: {
    annotations: if params.ingress.annotations != null then params.ingress.annotations else {},
  },
  spec+: {
    rules+: [
      {
        host: params.ingress.host,
        http: {
          paths: [
            {
              path: '/',
              pathType: 'Prefix',
              backend: {
                service: {
                  name: params.ingress.serviceName,
                  port: {
                    number: params.ingress.servicePort,
                  },
                },
              },
            },
          ],
        },
      },
    ],
    tls+: [
      {
        hosts: [ params.ingress.host ],
        secretName: params.ingress.secretName,
      },
    ],
  },
};

{
  [if params.ingress.enabled then '50_ingress']: ingress,
}
