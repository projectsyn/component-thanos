local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.thanos;
local argocd = import 'lib/argocd.libjsonnet';

local app = argocd.App('thanos', params.namespace);

{
  thanos: app,
}
