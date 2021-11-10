# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [v1.1.0]
### Fixed
Fix dependency conflict with kube-prometheus ([#9])

## [v1.0.0]

### Added

- Initial implementation ([#1])
- Deploy Thanos Store ([#2])
- Deploy Thanos Compactor ([#3])
- Deploy Thanos Bucket Web ([#4])

### Changed

- Disable dashboards by default ([#1])
- Upgrade to v0.18.0 ([#2])
- Update dependencies ([#6])
- Update dependencies ([#7])

### Fixed

- Render compactor alert rules ([#5])

[Unreleased]: https://github.com/projectsyn/component-thanos/compare/v1.0.0...HEAD
[v1.1.0]: https://github.com/projectsyn/component-thanos/releases/tag/v1.1.0
[v1.0.0]: https://github.com/projectsyn/component-thanos/releases/tag/v1.0.0

[#1]: https://github.com/projectsyn/component-thanos/pulls/1
[#2]: https://github.com/projectsyn/component-thanos/pulls/2
[#3]: https://github.com/projectsyn/component-thanos/pulls/3
[#4]: https://github.com/projectsyn/component-thanos/pulls/4
[#5]: https://github.com/projectsyn/component-thanos/pulls/5
[#6]: https://github.com/projectsyn/component-thanos/pulls/6
[#7]: https://github.com/projectsyn/component-thanos/pulls/7
[#9]: https://github.com/projectsyn/component-thanos/pulls/9
