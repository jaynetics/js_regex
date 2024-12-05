# encoding: utf-8
dir = File.expand_path(__dir__)
require File.join(dir, 'lib', 'js_regex', 'version')

Gem::Specification.new do |s|
  s.platform      = Gem::Platform::RUBY
  s.name          = 'js_regex'
  s.version       = LangRegex::VERSION
  s.license       = 'MIT'

  s.summary       = 'Converts Ruby regexes to JavaScript regexes.'
  s.description   = 'JsRegex converts Ruby\'s native regular expressions for '\
                    'JavaScript, taking care of various incompatibilities '\
                    'and returning warnings for unsolvable differences.'

  s.authors       = ['Janosch Müller']
  s.email         = ['janosch84@gmail.com']
  s.homepage      = 'https://github.com/jaynetics/js_regex'

  s.files         = Dir[File.join('lib', '**', '*.{csv,rb}')]

  s.required_ruby_version = '>= 2.1.0'

  s.add_dependency 'character_set', '~> 1.4'
  s.add_dependency 'regexp_parser', '>= 2.6.2', '< 3.0.0'
  s.add_dependency 'regexp_property_values', '~> 1.0'
end
