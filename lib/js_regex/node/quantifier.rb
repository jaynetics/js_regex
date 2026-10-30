class JsRegex::Node::Quantifier
  # Boundary between regexp_parser expressions and their quantifiers
  # and our internal representation.
  def self.from_expression(expression)
    return if (qtf = expression.quantifier).nil?

    new(qtf.min, qtf.max, reluctant: qtf.reluctant?)
  end

  def initialize(min, max, reluctant: false)
    self.min = min
    self.max = max
    self.reluctant = reluctant
  end

  def optional?
    min.zero?
  end

  def zero?
    max.zero?
  end

  def max_one?
    max == 1
  end

  def zero_or_one?
    optional? && max_one?
  end

  def unbounded?
    max < 0
  end

  def repeated?
    unbounded? || max > 1
  end

  def bounded_repetition?
    !unbounded? && max > 1
  end

  def minimum_at_most_one?
    min <= 1
  end

  def zero_or_more?
    optional? && unbounded?
  end

  def one_or_more?
    min == 1 && unbounded?
  end

  def fixed?
    min == max
  end

  def optional_iteration?(index)
    index > min
  end

  def remaining_minimum(consumed)
    [min - consumed, 0].max
  end

  def iteration_indices
    raise ArgumentError, 'cannot enumerate unbounded repetitions' if unbounded?

    (1..max)
  end

  def before_last_iteration?(index)
    index < max
  end

  def repeat_word(word)
    raise ArgumentError, 'variable repetition has no constant word' unless fixed?

    word * min
  end

  # Prefixes before one required iteration, in quantifier preference order.
  def prefix_counts
    minimum = remaining_minimum(1)
    counts = (0...minimum).map { |count| [count, count] } + [[minimum, -1]]
    reluctant? ? counts : counts.reverse
  end

  def with_minimum_one
    self.class.new(1, max, reluctant: reluctant?)
  end

  def reluctant?
    !!@reluctant
  end

  def to_s
    case [min, max]
    when [0, -1] then '*'
    when [1, -1] then '+'
    when [0, 1]  then '?'
    else
      if min == max
        "{#{min}}"
      else
        "{#{min},#{max < 0 ? '' : max}}"
      end
    end + (reluctant? ? '?' : '')
  end

  private

  attr_reader :min, :max

  def min=(arg)
    arg.instance_of?(Integer) ||
      raise(TypeError, "unsupported type #{arg.class} for #{__method__}")
    @min = arg
  end

  def max=(arg)
    arg.instance_of?(Integer) ||
      raise(TypeError, "unsupported type #{arg.class} for #{__method__}")
    @max = arg
  end

  def reluctant=(arg)
    arg == true || arg == false ||
      raise(TypeError, "unsupported type #{arg.class} for #{__method__}")
    @reluctant = arg
  end
end
