lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'facts/version'

Gem::Specification.new do |s|
  s.name               = 'facts'
  s.version            = Facts::VERSION
  s.platform           = Gem::Platform::RUBY
  s.summary            = %q{Client for the Facts REST API.}
  s.description        = %q{Facts is a framework for data snippet storage. This Gem is a client for the Facts RESTful API.}

  s.author             = 'Brandur Leach'
  s.email              = 'brandur@mutelight.org'
  s.homepage           = 'http://github.com/brandur/facts-cli'

  s.bindir             = 'bin'
  s.files              = Dir['lib/**/*', 'bin/*']
  s.executables        = %w(facts)
  s.default_executable = 'facts'
  s.require_paths      = %w(lib)

  s.add_dependency('json')
  s.add_dependency('rest-client')
  s.add_dependency('term-ansicolor')
  s.add_dependency('thor')

  s.add_development_dependency 'rspec'

  s.required_ruby_version = '>= 1.8.7'
  s.required_rubygems_version = ">= 1.3.6"
end

