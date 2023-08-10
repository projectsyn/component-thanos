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
  '1.22': '632032712f12eea0015aaef24ee1e14f38ef3e55',  // from: https://github.com/prometheus-operator/kube-prometheus/blob/5b9aa36169af47a1fb938cc7984d4ee59588fe2a/jsonnetfile.lock.json#L144
  '1.23': '17c576472d80972bfd3705e1e0a08e6f8da8e04b',  // from: https://github.com/prometheus-operator/kube-prometheus/blob/725b8bd3acd859663bcc67b615ac3b3888d33010/jsonnetfile.lock.json#L164
};

// To get the kube-thanos versions which are compatible with OCP4.x:
// Check the kube-thanos dependency version for each OCP4.x version in
// https://github.com/openshift/cluster-monitoring-operator in file
// https://github.com/openshift/cluster-monitoring-operator/blob/release-4.x/jsonnet/jsonnetfile.json
// Remember to map from OCP 4.x to K8s 1.x (4.7 -> 1.20, etc.)
// Note: We don't support OCP < 4.7, since OCP 4.6 and older are EOL.
local kube_thanos_version_map = {
  '1.20': 'release-0.17',  // corresponds to v0.17.0
  '1.21': 'release-0.19',  // corresponds to v0.19.0
  '1.22': 'release-0.22',  // corresponds to v0.22.0
};

local k8s_version = std.extVar('kubernetes_version');
local distribution = std.extVar('distribution');

local thanos_mixin_extver = std.extVar('thanos_mixin_version');
local thanos_mixin_version =
  if thanos_mixin_extver != '' then
    thanos_mixin_extver
  else if std.objectHas(thanos_mixin_version_map, k8s_version) then
    thanos_mixin_version_map[k8s_version]
  else
    // Use most recent version if we didn't find an entry in the map
    thanos_mixin_version_map['1.22'];

local kube_thanos_extver = std.extVar('kube_thanos_version');
local kube_thanos_version =
  if kube_thanos_extver != '' then
    kube_thanos_extver
  else if (
    distribution == 'openshift4' &&
    std.objectHas(kube_thanos_version_map, k8s_version)
  ) then
    kube_thanos_version_map[k8s_version]
  else
    'v0.23.0';

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
      version: kube_thanos_version,
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
