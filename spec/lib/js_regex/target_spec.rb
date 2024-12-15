require 'spec_helper'

describe LangRegex::Target do
  subject { LangRegex::Target }

  it 'can ::cast input to a supported target' do
    # default value
    expect(subject.cast(nil)).to eq subject::ES2009

    # available values
    expect(subject.cast('ES2009')).to eq subject::ES2009
    expect(subject.cast('ES2015')).to eq subject::ES2015
    expect(subject.cast('ES2018')).to eq subject::ES2018

    # supported input variations
    expect(subject.cast('ES2015')).to eq subject::ES2015
    expect(subject.cast('es2015')).to eq subject::ES2015
    expect(subject.cast('ES 2015')).to eq subject::ES2015
    expect(subject.cast(:ES2015)).to eq subject::ES2015
    expect(subject.cast('EcmaScript 2015')).to eq subject::ES2015
    expect(subject.cast('JS2015')).to eq subject::ES2015
    expect(subject.cast('JavaScript 2015')).to eq subject::ES2015
    expect(subject.cast('2015')).to eq subject::ES2015
    expect(subject.cast(2015)).to eq subject::ES2015

    # unsupported inputs
    expect { subject.cast('ES') }.to raise_error(ArgumentError)
    expect { subject.cast('ES42') }.to raise_error(ArgumentError)
    expect { subject.cast('Haskell 2015') }.to raise_error(ArgumentError)
    expect { subject.cast('Java 2015') }.to raise_error(ArgumentError)
    expect { subject.cast('15') }.to raise_error(ArgumentError)
    expect { subject.cast('') }.to raise_error(ArgumentError)
    expect { subject.cast(15) }.to raise_error(ArgumentError)
    expect { subject.cast(Object.new) }.to raise_error(ArgumentError)
    expect { subject.cast(true) }.to raise_error(ArgumentError)
    expect { subject.cast(false) }.to raise_error(ArgumentError)
  end
end
