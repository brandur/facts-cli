lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'facts/version'

task :build do
  puts 'Building gem'
  system('gem build facts.gemspec')
end

task :install => :build do
  puts 'Installing gem to system'
  system("gem install facts-#{Facts::VERSION}.gem")
end

