# coding: utf-8

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'date'
require 'sensu/extensions/influxdb2/version'

Gem::Specification.new do |spec|
  spec.name          = 'sensu-extensions-influxdb2'
  spec.version       = SensuExtensionsInfluxDB2::Version::VER_STRING
  spec.authors       = [
    'Critical Media',
    'Sensu-Plugins and contributors'
  ]
  spec.email = [
    '<steve.viola@criticalmedia.com>',
    '<sensu-users@googlegroups.com>'
  ]

  spec.summary       = 'Extension to get metrics and checks results into InfluxDB'
  spec.description   = 'Extension to get metrics and checks results into InfluxDB'
  spec.homepage      = 'https://github.com/criticalmedia/sensu-extensions-influxdb'

  spec.files         = Dir.glob('{bin,lib}/**/*') + %w(LICENSE README.md)
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'sensu-extension'
  spec.add_runtime_dependency 'em-http-request', '~> 1.1'
  spec.add_runtime_dependency 'multi_json'

  spec.add_development_dependency 'bundler', '~> 1.6'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'redcarpet', '~> 3.2'
  spec.add_development_dependency 'rubocop', '~> 0.40.0'
  spec.add_development_dependency 'sensu-logger'
  spec.add_development_dependency 'sensu-settings'
  spec.add_development_dependency 'github-markup', '~> 1.3'
  spec.add_development_dependency 'yard', '~> 0.8'
end
