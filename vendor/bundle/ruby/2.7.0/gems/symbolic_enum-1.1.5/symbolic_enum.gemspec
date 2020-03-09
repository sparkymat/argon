# frozen_string_literal: true

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'symbolic_enum/version'

Gem::Specification.new do |spec|
  spec.name          = 'symbolic_enum'
  spec.version       = SymbolicEnum::VERSION
  spec.authors       = ['Ajith Hussain']
  spec.email         = ['csy0013@googlemail.com']

  spec.summary       = %q{symbolic_enum is an alternative implementation of Rails enum which always returns symbols and works with array as well.}
  spec.homepage      = 'https://github.com/sparkymat/symbolic_enum'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 2.1'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.9'
  spec.add_development_dependency 'rails'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'pry-byebug'
end
