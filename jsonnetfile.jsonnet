// To get the hash:
// For each kubernetes version check the release version of kube-prometheus here:
// https://github.com/projectsyn/component-rancher-monitoring/blob/master/class/defaults.yml#L5
// Then get the hash from: https://github.com/prometheus-operator/kube-prometheus/blob/<release_version>/jsonnetfile.lock.json
// Where <release_version> matches the string in the map from the first link
local thanos_mixin_version_map = {
  '1.18': '79d8cfdc1a00f8a96475d5d1ff1a852b184b146e',
  '1.19': '79d8cfdc1a00f8a96475d5d1ff1a852b184b146e',
  '1.20': '09b36547e5ed61a32a309648a8913bd02c08d3cc',
  '1.21': 'ff363498fc95cfe17de894d7237bcf38bdd0bc36',
  '1.22': 'ff363498fc95cfe17de894d7237bcf38bdd0bc36',  // from: https://github.com/prometheus-operator/kube-prometheus/blob/release-0.9/jsonnetfile.lock.json#L144
};

local k8s_version = std.extVar('kubernetes_version');

local thanos_mixin_extver = std.extVar('thanos_mixin_version');
local thanos_mixin_version =
  if thanos_mixin_extver != '' then
    thanos_mixin_extver
  else if std.objectHas(thanos_mixin_version_map, k8s_version) then
    thanos_mixin_version_map[k8s_version]
  else
    // Use most recent version if we didn't find an entry in the map
    thanos_mixin_version_map['1.22'];

{
  version: 1,
  dependencies: [
    {
      source: {
        git: {
          remote: 'https://github.com/thanos-io/kube-thanos.git',
          subdir: 'jsonnet/kube-thanos',
        },
      },
      version: 'v0.23.0',
    },
    {
      source: {
        git: {
          remote: 'https://github.com/thanos-io/thanos.git',
          subdir: 'mixin',
        },
      },
      version: thanos_mixin_version,
    },
  ],
  legacyImports: true,
}
