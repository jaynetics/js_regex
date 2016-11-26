# encoding: utf-8
# frozen_string_literal: true

require 'spec_helper'

describe JsRegex::Conversion do
  describe '::of' do
    let(:return_value) { described_class.of(/foo/i) }

    it 'returns an Array' do
      expect(return_value).to be_an(Array)
    end

    it 'includes a source String at index 0' do
      expect(return_value[0]).to be_a(String)
    end

    it 'includes an options String at index 1' do
      expect(return_value[1]).to be_a(String)
    end

    it 'includes a warnings Array at index 2' do
      expect(return_value[2]).to be_an(Array)
    end

    it 'performs a sanity check before returning' do
      expect_any_instance_of(described_class).to receive(:perform_sanity_check)
      described_class.of(//)
    end
  end

  describe '#convert_source' do
    it 'passes the regexp to Scanner and forwards the output to converters' do
      regexp = //
      expect(Regexp::Scanner)
        .to receive(:scan)
        .with(regexp)
        .and_yield(:literal, :foo, :bar, :fizz, :buzz)
      expect_any_instance_of(JsRegex::Converter::LiteralConverter)
        .to receive(:convert)
        .with(:literal, :foo, :bar, :fizz, :buzz)
      described_class.of(regexp)
    end
  end

  describe '#converter_for_token_class' do
    it 'finds fitting converters for tokens' do
      conversion = described_class.new(//)
      converter = conversion.send(:converter_for_token_class, :literal)
      expect(converter).to be_a(JsRegex::Converter::LiteralConverter)
    end

    it 'falls back to the UnsupportedTokenConverter' do
      converter = described_class.new(//).send(:converter_for_token_class, :foo)
      expect(converter).to be_a(JsRegex::Converter::UnsupportedTokenConverter)
    end

    it 'initializes the converters with self as target and self.context' do
      conversion = described_class.new(//)
      converter = conversion.send(:converter_for_token_class, :foo)
      expect(converter.target).to eq(conversion)
      expect(converter.context).to eq(conversion.context)
    end
  end

  describe '#convert_options' do
    it 'always sets the global flag' do
      given_the_ruby_regexp(//)
      expect(@js_regex.options).to eq('g')
    end

    it 'carries over the case-insensitive option' do
      given_the_ruby_regexp(/a/i)
      expect(@js_regex.options).to eq('gi')
      expect_no_warnings
      expect_ruby_and_js_to_match(string: 'ABab', with_results: %w(A a))
    end

    it 'does not carry over the multiline option' do
      # this would be bad since JS' multiline option is different from Ruby's.
      # c.f. meta_converter_spec.rb for option-based token handling.
      given_the_ruby_regexp(//m)
      expect(@js_regex.options).to eq('g')
      expect_no_warnings
    end

    it 'does not carry over the extended option' do
      # c.f. freespace_converter_spec.rb for option-based token handling.
      given_the_ruby_regexp(//x)
      expect(@js_regex.options).to eq('g')
      expect_no_warnings
    end
  end

  describe '#perform_sanity_check' do
    let(:conversion) { described_class.new(/abc/) }

    it 'puts the calculated source through Regexp#new' do
      conversion # init
      expect(Regexp).to receive(:new).with('abc')
      conversion.send(:perform_sanity_check)
    end

    context 'if the source is ok' do
      it 'does nothing' do
        expect { conversion.send(:perform_sanity_check) }
          .not_to change { [conversion.source, conversion.warnings] }
      end
    end

    context 'if there is an error in the source' do
      # manually inject illegal source
      before { conversion.source.replace('[') }

      it 'sets source to empty' do
        expect { conversion.send(:perform_sanity_check) }
          .to change { conversion.source }.from('[').to('')
      end

      it 'adds a warning' do
        expect { conversion.send(:perform_sanity_check) }
          .to change { conversion.warnings.count }.by(1)
        expect(conversion.warnings.last).to be_a(String)
      end
    end

    context 'if there is an ArgumentError' do
      before { allow(Regexp).to receive(:new).and_raise(ArgumentError) }

      it 'applies' do
        expect { conversion.send(:perform_sanity_check) }
          .to change { conversion.warnings.count }.by(1)
      end
    end

    context 'if there is a RegexpError' do
      before { allow(Regexp).to receive(:new).and_raise(RegexpError) }

      it 'applies' do
        expect { conversion.send(:perform_sanity_check) }
          .to change { conversion.warnings.count }.by(1)
      end
    end

    context 'if there is a SyntaxError' do
      before { allow(Regexp).to receive(:new).and_raise(SyntaxError) }

      it 'applies' do
        expect { conversion.send(:perform_sanity_check) }
          .to change { conversion.warnings.count }.by(1)
      end
    end
  end
end
