require 'spec_helper'

describe LangRegex::Converter::KeepConverter do
  it 'drops the keep mark "\K" with warning', targets: [ES2009, ES2015] do
    expect(/a\Kb/).to\
    become(/ab/).with_warning('ES2018')
  end

  it 'converts root-level keep marks to a lookbehind on ES2018+', targets: [ES2018] do
    expect(/a\Kb/).to\
    become(/(?<=a)b/)
  end

  it 'drops nested keep marks on ES2018+', targets: [ES2018] do
    # This special case that can't be reproduced with a normal lookbehind
    # because the keep mark works across group boundaries.
    # /a(b\Kc)/ =~ 'abc'; $~ # => #<MatchData "c" 1:"bc">
    expect(/a(b\Kc)d/).to\
    become(/a(bc)d/).with_warning('nested keep mark')
  end
end
