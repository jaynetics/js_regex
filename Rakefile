# frozen_string_literal: true

require 'bundler/gem_tasks'

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new

task mutate: :spec do
  arguments = %w(
    bundle exec mutant
    --fail-fast
    --include lib
    --require js_regex
    --use rspec
    --ignore-subject JsRegex::Conversion#initialize
    --ignore-subject JsRegex::Converter::Context*
    -- JsRegex*
  )

  system(*arguments) || raise('Mutant task is not successful')
end

if Gem::Version.new(RUBY_VERSION.dup) >= Gem::Version.new('2.3.1')
  task default: :mutate
else
  task default: :spec
end
