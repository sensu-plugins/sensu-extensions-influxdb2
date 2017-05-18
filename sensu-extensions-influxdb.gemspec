# coding: utf-8

Gem::Specification.new do |spec|
  spec.name          = 'sensu-extensions-influxdb'
  spec.version       = '0.0.2'
  spec.authors       = ['Critical Media']
  spec.email         = ['<steve.viola@criticalmedia.com>']

  spec.summary       = 'Extension to get metrics and checks results into InfluxDB'
  spec.description   = 'Extension to get metrics and checks results into InfluxDB'
  spec.homepage      = 'https://github.com/criticalmedia/sensu-extensions-influxdb'

  spec.files         = Dir.glob('{bin,lib}/**/*') + %w(LICENSE README.md)
  spec.require_paths = ['lib']

  spec.add_dependency 'sensu-extension'
  spec.add_dependency 'em-http-request'
  spec.add_dependency 'multi_json'

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
