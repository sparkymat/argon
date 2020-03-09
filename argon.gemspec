# coding: utf-8
# frozen_string_literal: true

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'argon/version'

Gem::Specification.new do |spec|
  spec.name          = 'argon'
  spec.version       = Argon::VERSION
  spec.authors       = ['Ajith Hussain']
  spec.email         = ['csy0013@googlemail.com']

  spec.summary       = 'Argon generates a workflow engine (built around a state machine)'
  spec.homepage      = 'https://github.com/sparkymat/argon'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 2.1'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'pry-byebug'
  spec.add_development_dependency 'rails'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.9'
  spec.add_development_dependency 'symbolic_enum', '~> 1.1', '>= 1.1.4'
end
