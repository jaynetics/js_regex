# frozen_string_literal: true

require_relative 'analysis'
require_relative 'literal_word'

class JsRegex::SecondPass::Compiler::LowerKeepMarks
  Compiler = JsRegex::SecondPass::Compiler

  def self.call(expression)
    found = false
    Compiler.walk(expression) { |part| found ||= part.kind == :keep }
    return expression unless found

    new(expression).rewrite(expression)
  end

  def initialize(expression)
    @analysis = Compiler::Analysis.new(expression)
    root = Compiler.unwrap(expression)
    branches = root.kind == :choice ? root.children.reject { |child| child.kind == :omitted_branch } : [root]
    widths = branches.map do |branch|
      last = branch.children.rindex { |child| !child.instance_of?(String) && child.kind == :keep }
      last ? prefix_width(Compiler::Expression.new(:sequence, branch.children.take(last))) : 0
    end
    unless widths.none?(&:nil?) && (widths.uniq.one? || literal_alternatives_safe?(branches, widths))
      raise Compiler::Unsupported, 'keep-mark prefixes with unproven search order'
    end
  end

  def rewrite(expression)
    return expression if expression.instance_of?(String)

    children = expression.children.map { |child| rewrite(child) }
    last = children.rindex { |child| !child.instance_of?(String) && child.kind == :keep }
    if last
      unless [:sequence, :branch].include?(expression.kind)
        raise Compiler::Unsupported, 'keep mark outside a converter sequence'
      end
      prefix = children.take(last).reject { |child| !child.instance_of?(String) && child.kind == :keep }
      children = [Compiler::Expression.new(:lookbehind, prefix), *children.drop(last + 1)]
    end
    children == expression.children ? expression : expression.with(children: children)
  end

  private

  # Unequal keep offsets can reverse two matches' search order. For complete
  # literal alternatives, check every relative start that could cause this.
  # Non-ASCII case folding needs a broader proof; keep it out.
  def literal_alternatives_safe?(branches, offsets)
    words = branches.map do |branch|
      children = branch.children.reject { |child| !child.instance_of?(String) && child.kind == :keep }
      Compiler::LiteralWord.call(branch.with(children: children))
    end
    return false unless words.all? { |word| word && word.ascii_only? }
    # The tree does not carry the final i flag. Prove both cases by allowing
    # ASCII case-insensitive overlap even for case-sensitive conversions.
    words.map!(&:downcase)
    words.each_index.all? do |left|
      # Empty matches advance one character before the next global search.
      boundary = words[left].length + (words[left].length == offsets[left] ? 1 : 0)
      words.each_index.all? do |right|
        difference = offsets[left] - offsets[right]
        # At the same returned start, equal lengths give the same substring.
        # This cannot excuse selecting a different branch's captures.
        same_result = @analysis.captures.empty? && words[left].length - offsets[left] == words[right].length - offsets[right]
        reordered = (0..difference).any? do |distance|
          next false if distance.zero? && left >= right
          wins = distance < difference || (right < left && !same_result)
          wins && compatible_at?(words[left], words[right], distance)
        end

        # A later global match must not reuse a prefix consumed by this one.
        reused = ([0, boundary - offsets[right]].max...boundary).any? do |distance|
          next false if distance.zero? && left > right
          compatible_at?(words[left], words[right], distance)
        end
        !reordered && !reused
      end
    end
  end

  def compatible_at?(left, right, distance)
    length = [left.length - distance, right.length].min
    length <= 0 || left[distance, length] == right[0, length]
  end

  # A lookbehind commits its prefix and evaluates it backwards. Only accept
  # prefixes whose captures and participation cannot change on backtracking.
  # Equal offsets across root alternatives preserve first-match search order.
  # More general keep marks need forward matching, not just a width check.
  def prefix_width(expression)
    if expression.instance_of?(String)
      word = Compiler::LiteralWord.call(expression)
      return word.length if word
      return
    end

    case expression.kind
    when :keep, :dropped, :omitted_branch then 0
    when :backreference, :value
      word = Compiler::LiteralWord.call(@analysis.captures.fetch(expression.reference))
      word.length if word
    when :sequence, :branch, :group, :capture
      widths = expression.children.map { |child| prefix_width(child) }
      widths.sum if widths.none?(&:nil?)
    when :repeat
      quantity = expression.quantity
      return 0 if quantity.max.zero?
      return unless quantity.min == quantity.max
      return if quantity.max > 1 && @analysis[expression].definitions.any?
      width = prefix_width(expression.children.first)
      width * quantity.min if width
    when :history, :multiplex
      widths = expression.children.map { |child| prefix_width(child) }
      widths.first if widths.none?(&:nil?) && widths.uniq.one?
    end
  end
end
