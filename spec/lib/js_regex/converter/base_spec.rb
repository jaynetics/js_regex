require 'spec_helper'

js_converter = LangRegex::JsRegex.js_converter

describe LangRegex::Converter::Base do
  describe '#warn_of_unsupported_feature' do
    it 'adds a warning with token class, subtype, data and index' do
      conv = described_class.new(js_converter)
      expr = expression_double(type: 'bar', token: 'big_bad', ts: 7)
      allow(expr).to receive(:to_s).and_return('foo')
      allow(conv).to receive(:expression).and_return(expr)
      allow(conv).to receive(:warn_of)
      conv.send(:warn_of_unsupported_feature)
      expect(conv).to have_received(:warn_of).with(
        "Dropped unsupported big bad bar 'foo' at index 7"
      )
    end

    it 'takes an argument to override the description' do
      conv = described_class.new(js_converter)
      expr = expression_double(type: 'bar', token: 'big', ts: 7)
      allow(expr).to receive(:to_s).and_return('foo')
      allow(conv).to receive(:expression).and_return(expr)
      allow(conv).to receive(:warn_of)
      conv.send(:warn_of_unsupported_feature, 'fizz')
      expect(conv).to have_received(:warn_of).with(
        "Dropped unsupported fizz 'foo' at index 7"
      )
    end

    it 'returns a dropped node that appends as an empty string' do
      conv = described_class.new(js_converter)
      expr = expression_double(type: 'bar', token: 'big', ts: 7)
      allow(expr).to receive(:to_s).and_return('foo')
      allow(conv).to receive(:expression).and_return(expr)
      allow(conv).to receive(:warn_of)

      node = conv.send(:warn_of_unsupported_feature, 'fizz')

      expect(node.type).to eq :dropped
      expect(node.to_s).to eq ''
    end
  end

  describe '#convert' do
    context 'when quantifiers are greedy (default)' do
      it 'preserves zero-or-ones (?)' do
        expect(/a?/).to stay_the_same
      end

      it 'preserves zero-or-mores (*)' do
        expect(/a*/).to stay_the_same
      end

      it 'preserves one-or-mores (+)' do
        expect(/a+/).to stay_the_same
      end

      it 'preserves fixes ({x})' do
        expect(/a{4}/).to stay_the_same
      end

      it 'preserves ranges ({x,y})' do
        expect(/a{6,8}/).to stay_the_same
      end

      it 'converts an implicit min value of 0 to an explicit one ({,y})' do
        expect(/a{,8}/).to become(/a{0,8}/)
      end

      it 'preserves set quantifiers' do
        expect(/[a-z]{6,8}/).to stay_the_same
      end

      it 'preserves group quantifiers' do
        expect(/(?:a|b){6,8}/).to stay_the_same
      end
    end

    context 'when quantifiers are reluctant' do
      it 'preserves zero-or-ones (??)' do
        expect(/a??/).to stay_the_same
      end

      it 'preserves zero-or-mores (*?)' do
        expect(/a*?/).to stay_the_same
      end

      it 'preserves one-or-mores (+?)' do
        expect(/a+?/).to stay_the_same
      end

      it 'preserves set quantifiers' do
        expect(/[a-z]+?/).to stay_the_same
      end

      it 'preserves group quantifiers' do
        expect(/(?:a|b)+?/).to stay_the_same
      end
    end

    context 'when quantifiers are possessive' do
      it 'emulates possessiveness for zero-or-ones (?+)' do
        expect(/a?+/).to\
        become(/(?=(a?))\1(?:)/)
      end

      it 'emulates possessiveness for zero-or-mores (*+)' do
        expect(/a*+/).to\
        become(/(?=(a*))\1(?:)/)
      end

      it 'emulates possessiveness for one-or-mores (++)' do
        expect(/a++/).to\
        become(/(?=(a+))\1(?:)/)
      end

      it 'emulates possessiveness for set quantifiers' do
        expect(/[a-z]++/).to\
        become(/(?=([a-z]+))\1(?:)/)
      end

      it 'emulates possessiveness for group quantifiers' do
        expect(/(?:a|b)++/).to\
        become(/(?=((?:a|b)+))\1(?:)/)
      end

      it 'takes into account preceding active groups for the backreference' do
        expect(/(a)(b)(c)_d++/).to\
        become(/(a)(b)(c)_(?=(d+))\4(?:)/)
      end

      it 'isnt confused by preceding passive groups' do
        expect(/(?:c)_a++/).to\
        become(/(?:c)_(?=(a+))\1(?:)/)
      end

      it 'isnt confused by preceding lookahead groups' do
        expect(/(?=c)_a++/).to\
        become(/(?=c)_(?=(a+))\1(?:)/)
      end

      it 'isnt confused by preceding negative lookahead groups' do
        expect(/(?!=x)_a++/).to\
        become(/(?!=x)_(?=(a+))\1(?:)/)
      end
    end

    context 'when there are multiple quantifiers' do
      it 'wraps adjacent/multiplicative fixes ({x}) in passive groups' do
        expect(/a{4}{6}/).to\
        become(/(?:a{4}){6}/)
      end

      it 'wraps adjacent/multiplicative ranges ({x,y}) in passive groups' do
        expect(/a{2,4}{3,6}/).to\
        become(/(?:a{2,4}){3,6}/)
      end

      it 'wraps mixed adjacent quantifiers in passive groups' do
        expect(/ab{2,3}*/).to\
        become(/a(?:b{2,3})*/)
      end

      it 'wraps multiple adjacent quantifiers in passive groups' do
        expect(/ab{2}{3}{4}{5}/).to\
        become(/a(?:(?:(?:b{2}){3}){4}){5}/)
      end

      it 'preserves distinct quantifiers' do
        expect(/a{2}b{2}c{2,3}d{2,3}e+f+g?h?i*j*/)
          .to stay_the_same
          .and keep_matching('aabbccdddefghi', with_results: %w[aabbccdddefghi])
      end
    end

    context 'when quantifiers follow dropped elements' do
      it 'drops the quantifiers as well' do
        expect(/a\G++b/).to\
        become(/ab/).with_warning
      end
    end
  end

  describe '#convert_subexpressions' do
    it 'concatenates the conversion result of multiple subexpressions' do
      expect(/(a|b)/).to stay_the_same
    end
  end

  describe '#drop_without_warning' do
    it 'returns an empty string to be appended to the source' do
      expect(described_class.new(js_converter).send(:drop_without_warning).to_s).to eq('')
    end

    it 'does not generate warnings' do
      converter = described_class.new(js_converter)
      context = LangRegex::Converter::Context.new
      allow(converter).to receive(:context).and_return(context)
      expect { described_class.new(js_converter).send(:drop_without_warning) }
        .not_to(change { context.warnings.count })
    end
  end

  describe '#warn_of' do
    it 'adds a warning to the context' do
      converter = described_class.new(js_converter)
      context = LangRegex::Converter::Context.new
      allow(converter).to receive(:context).and_return(context)
      expect { converter.send(:warn_of, 'foo') }
        .to(change { context.warnings }.from([]).to(['foo']))
    end
  end

  describe '#wrap_in_backrefed_lookahead' do
    let(:converter) { described_class.new(js_converter) }
    let(:context) { LangRegex::Converter::Context.new }
    before { allow(converter).to receive(:context).and_return(context) }

    it 'returns the contents wrapped in a backreferenced lookahead' do
      result = converter.send(:wrap_in_backrefed_lookahead, %w[foo bar])
      expect(result.to_s).to eq('(?=(foobar))\\1(?:)')
      expect(result.children[4].type).to eq :backref
      expect(result.children[4].children).to eq %w[\\1]
    end

    it 'increases the count of captured groups' do
      expect { converter.send(:wrap_in_backrefed_lookahead, 'foo') }
        .to change { context.send(:capturing_group_count) }.from(0).to(1)
    end

    it 'increases the new_capturing_group_position for any following group' do
      context.capture_group
      expect(context.new_capturing_group_position(1)).to eq(1)
      expect(converter.send(:wrap_in_backrefed_lookahead, 'foo').to_s).to include '\2'
      expect(context.new_capturing_group_position(2)).to eq(3)
      expect(converter.send(:wrap_in_backrefed_lookahead, 'foo').to_s).to include '\3'
    end

    it 'doesnt increase the new_capturing_group_position of preceding groups' do
      context.capture_group
      expect(context.new_capturing_group_position(1)).to eq(1)
      expect(converter.send(:wrap_in_backrefed_lookahead, 'foo').to_s).to include '\2'
      expect(context.new_capturing_group_position(1)).to eq(1)
    end
  end
end
