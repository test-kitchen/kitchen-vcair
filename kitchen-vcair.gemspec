# Encoding: UTF-8

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'kitchen/driver/vcair_version'

Gem::Specification.new do |spec|
  spec.name          = 'kitchen-vcair'
  spec.version       = Kitchen::Driver::VCAIR_VERSION
  spec.authors       = ['Chef Partner Engineering', 'Taylor Carpenter', 'Chris McClimans']
  spec.email         = %w(partnereng@chef.io wolfpack+c+t@vulk.co)
  spec.description   = 'A Test Kitchen vCloud Air driver'
  spec.summary       = 'A Test Kitchen vCloud Air driver built on Fog'
  spec.homepage      = 'https://github.com/chef-partners/kitchen-vcair'
  spec.license       = 'Apache 2.0'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = %w(lib)

  spec.required_ruby_version = '>= 3.1'

  spec.add_dependency 'test-kitchen', ">= 1.1", "< 4.0"
  spec.add_dependency 'fog-vmfusion'
end
