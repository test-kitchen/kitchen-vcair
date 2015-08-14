# Encoding: UTF-8

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'kitchen/driver/vcair_version'

Gem::Specification.new do |spec|
  spec.name          = 'kitchen-vcair'
  spec.version       = Kitchen::Driver::VCAIR_VERSION
  spec.authors       = ['Taylor Carpenter', 'Chris McClimans']
  spec.email         = %w(wolfpack+c+t@vulk.co)
  spec.description   = 'A Test Kitchen vCloud Air driver'
  spec.summary       = 'A Test Kitchen vCloud Air driver built on Fog'
  spec.homepage      = 'https://github.com/vulk/kitchen-vcair'
  spec.license       = 'Apache'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = %w(lib)

  spec.required_ruby_version = '>= 1.9.3'

  spec.add_dependency 'test-kitchen', '~> 1.1'
  spec.add_dependency 'pester'
  spec.add_dependency 'fog', '~> 1.18'

  spec.add_development_dependency 'bundler', '~> 1.0'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rubocop', '~> 0.29'
  spec.add_development_dependency 'cane', '~> 2.6'
  spec.add_development_dependency 'countloc', '~> 0.4'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'simplecov', '~> 0.9'
  spec.add_development_dependency 'simplecov-console', '~> 0.2'
  spec.add_development_dependency 'coveralls', '~> 0.8'
end
