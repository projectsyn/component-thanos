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
      version: std.extVar('thanos_mixin_version'),
    },
  ],
  legacyImports: true,
}
