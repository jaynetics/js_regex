Dir['tasks/**/*.rake'].each { |file| load(file) }

require 'bundler/gem_tasks'

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new

task default: :spec
