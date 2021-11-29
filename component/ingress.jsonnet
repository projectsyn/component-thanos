local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local inv = kap.inventory();
local params = inv.parameters.thanos;
local instance = inv.parameters._instance;

local hostName = if std.length(params.ingress.host) == 0 then error 'ingress.host cannot be empty' else params.ingress.host;

local ingress = kube.Ingress('%s' % instance) {
  apiVersion: 'networking.k8s.io/v1',  // kube.Ingress creates version with 'v1beta1'
  metadata+: {
    annotations: if params.ingress.annotations != null then params.ingress.annotations else {},
  },
  spec+: {
    rules+: [
      {
        host: hostName,
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
        hosts: [ hostName ],
        secretName: params.ingress.secretName,
      },
    ],
  },
};

{
  [if params.ingress.enabled then '50_ingress']: ingress,
}
