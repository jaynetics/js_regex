# encoding: utf-8
Gem::Specification.new do |s|
  s.platform      = Gem::Platform::RUBY
  s.name          = 'js_regex'
  s.version       = '1.0.17'
  s.license       = 'MIT'

  s.summary       = 'Converts Ruby regexes to JavaScript regexes.'
  s.description   = 'JsRegex converts Ruby\'s native regular expressions for '\
                    'JavaScript, taking care of various incompatibilities '\
                    'and returning warnings for unsolvable differences.'

  s.authors       = ['Janosch Müller']
  s.email         = ['janosch84@gmail.com']
  s.homepage      = 'https://github.com/janosch-x/js_regex'

  s.files         = Dir[File.join('lib', '**', '*.rb')]

  s.add_dependency 'regexp_parser', '0.3.6'

  s.add_development_dependency 'rake', '~> 11.1'
  s.add_development_dependency 'rspec-core', '~> 3.4'
  s.add_development_dependency 'rspec-expectations', '~> 3.4'
  s.add_development_dependency 'therubyracer', '~> 0.12'

  if Gem::Version.new(RUBY_VERSION.dup) >= Gem::Version.new('2.2.2')
    s.add_development_dependency 'codeclimate-test-reporter', '~> 0.5'
  end
end
