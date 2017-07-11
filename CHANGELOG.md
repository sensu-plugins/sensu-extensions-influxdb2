#Change Log
This project adheres to [Semantic Versioning](http://semver.org/).

This CHANGELOG follows the format listed at [Keep A Changelog](http://keepachangelog.com/)

## [Unreleased]
### Added
- Proxy_mode
- Basic auth authentication option.
- Filters
- Measurement templating mechanism
- Append check and client tags to metrics

### Fixed
- strip_key was not working

## 0.0.2 - 2017-05-18
### Added
- Add rubocop checks and fixes the code to pass them (@luisdavim)
- Add option to configure strip_metric from the check definition (@luisdavim)

## 0.0.1 - 2017-04-19
### Added
- Change sensu-influxdb-extension into a gem (@stevenviola)
