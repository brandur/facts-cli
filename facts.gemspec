Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'facts'
  s.version     = '0.1'
  s.summary     = 'Client for the Facts REST API.'
  s.description = 'Facts is a framework for data snippet storage. This Gem is a client for the Facts RESTful API.'

  s.required_ruby_version = '>= 1.8.7'
  s.required_rubygems_version = ">= 1.3.6"

  s.author   = 'Brandur Leach'
  s.email    = 'brandur@mutelight.org'
  s.homepage = 'http://facts.brandur.org'

  s.bindir = 'bin'
  s.executables = ['facts']
  s.default_executable = 'facts'
  s.files = Dir['lib/**/*', 'bin/*']

  s.add_dependency('json')
  s.add_dependency('rest-client')
  s.add_dependency('term-ansicolor')
end
