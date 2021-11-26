local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local inv = kap.inventory();
local params = inv.parameters.thanos;
local instance = inv.parameters._instance;

local ingress = kube.Ingress('%s' % instance) {
  metadata+: {
    annotations: params.ingress.annotations,
  },
  spec+: {
    rules+: [
      {
        http: {
          paths: [
            {
              path: '/',
              pathType: 'Prefix',
              backend: {
                service: {
                  name: params.ingress.serviceName,
                  port: {
                    number: 9090,
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
        hosts: [
          if std.length(params.ingress.host) == 0 then error 'ingress.host cannot be empty' else params.ingress.host,
        ],
        secretName: params.ingress.secretName,
      },
    ],
  },
};

{
  [if params.ingress.enabled then '50_ingress']: ingress,
}
