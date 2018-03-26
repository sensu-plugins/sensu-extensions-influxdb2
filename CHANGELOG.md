#Change Log
This project adheres to [Semantic Versioning](http://semver.org/).

This CHANGELOG follows the format located [here](https://github.com/sensu-plugins/community/blob/master/HOW_WE_CHANGELOG.md)

## [Unreleased]

### Added
- Proxy_mode
- Basic auth authentication option.
- Filters
- Measurement templating mechanism
- Append check and client tags to metrics
- Enhaced history metrics: outputs all history metrics into a single measurement, adding subscribers and check name as tags (@alcasim)

### Fixed
- strip_key was not working

### Changed
- updated changelog guidelines location (@majormoses)

## 0.0.2 - 2017-05-18
### Added
- Add rubocop checks and fixes the code to pass them (@luisdavim)
- Add option to configure strip_metric from the check definition (@luisdavim)

## 0.0.1 - 2017-04-19
### Added
- Change sensu-influxdb-extension into a gem (@stevenviola)
