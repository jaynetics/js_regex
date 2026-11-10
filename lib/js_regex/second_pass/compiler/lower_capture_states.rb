# frozen_string_literal: true

require_relative 'analysis'
require_relative 'specialize'
require_relative 'literal_word'
require_relative 'capture_histories'

class JsRegex::SecondPass::Compiler::LowerCaptureStates
  Compiler = JsRegex::SecondPass::Compiler
  Expression = Compiler::Expression
  NotApplicable = Class.new(StandardError)
  attr_reader :split_captures

  def self.call(expression, analysis: nil)
    pass = new(expression, analysis)
    result = pass.rewrite(expression)
    Compiler::CaptureHistories.call(result, pass.split_captures)
  end

  def initialize(expression, analysis)
    @analysis = analysis || Compiler::Analysis.new(expression)
    @references = @analysis[expression].references
    @split_captures = []
  end

  def rewrite(expression)
    return expression if expression.instance_of?(String)
    return expression unless [:sequence, :group, :capture, :branch, :choice, :lookahead, :negative_lookahead, :atomic].include?(expression.kind)

    unless [:choice, :atomic].include?(expression.kind)
      expression.children.each.with_index do |child, index|
        next unless candidate?(child)

        next unless @analysis.closed?(expression.children.drop(index))
        following = Expression.new(:sequence, expression.children.drop(index + 1))

        begin
          machine = Machine.new(child, following)
          replacement = machine.compile
        rescue NotApplicable
          next
        end
        @split_captures |= machine.retained_captures
        prefix = expression.children.take(index).map { |part| rewrite(part) }
        return expression.with(children: [*prefix, replacement])
      end
    end
    children = expression.children.map { |child| rewrite(child) }
    children == expression.children ? expression : expression.with(children: children)
  end

  private

  def candidate?(expression)
    return false if expression.instance_of?(String) || expression.kind != :repeat
    quantity = expression.quantity
    return false unless quantity.max < 0 && quantity.min <= 1 && quantity.mode != :possessive

    body = @analysis[expression.children.first]
    body.definitions.any? do |ref|
      @references.fetch(ref, 0) > 0 &&
        (!body.must_capture.include?(ref) || body.references.fetch(ref, 0) > 0 || body.empty != :never)
    end
  end

  # Participation is monotone: each successful capture sets one bit. Only
  # constant values (or values never read) may be represented by these bits.
  # Self-loops stay as native quantifiers; transitions to new states are acyclic.
  class Machine
    attr_reader :retained_captures

    def initialize(loop_expression, following)
      @body = loop_expression.children.first
      @following = following
      @quantity = loop_expression.quantity
      region = Expression.new(:sequence, [@body, following])
      @analysis = Compiler::Analysis.new(region)
      references = @analysis[region].references
      tracked = @analysis[@body].definitions.select { |ref| references.fetch(ref, 0) > 0 }
      # A consuming whole-iteration capture always overwrites its value. Keep
      # its physical values in the emitted paths and join the copies afterward;
      # only the independently retained inner values need finite-state tracking.
      wrappers = Compiler.capture_chain(Compiler.unwrap(@body)).select do |capture|
        capture.nonempty && !@analysis[@body].references.key?(capture.reference)
      end
      tracked -= wrappers.map(&:reference)
      @retained_captures = wrappers.map { |capture| capture.reference.capture }
      raise NotApplicable if tracked.empty?
      raise NotApplicable unless (@analysis[@body].references.keys & @analysis[following].definitions).empty?

      @bits = tracked.each_with_index.to_h { |ref, index| [ref, 1 << index] }
      @full = (1 << tracked.length) - 1
      @values = tracked.to_h do |ref|
        capture = @analysis.captures.fetch(ref)
        value = word(capture)
        raise NotApplicable if value.nil? && @analysis.value_uses.fetch(ref, []).any?
        [ref, value]
      end
      # A sole capture covering the iteration cannot retain an empty value from
      # a different position across a consuming iteration. Its zero-width paths
      # can therefore stop in place once participation no longer changes.
      @nullable_scalar = @analysis[@body].definitions.one? &&
        Compiler.unwrap(@body).kind == :capture && @analysis[@body].empty != :never
      @memo = {}
    end

    def compile
      return remaining(0) if @quantity.min.zero?

      choose(iterations(0).map { |part, state| sequence(part, remaining(state)) })
    end

    private

    def remaining(state)
      return Compiler.copy(@memo[state]) if @memo.key?(state)

      tail = Compiler.copy(substitute(@following, state))
      result = if state == @full && !@nullable_scalar
                 sequence(repeat(Compiler.copy(substitute(@body, state)), lazy?), tail)
               else
                 empty_exit = false
                 options = iterations(state).map do |part, next_state, empty|
                   if next_state != state
                     [nil, sequence(part, remaining(next_state))]
                   elsif @nullable_scalar && empty == :always
                     next if lazy? # The same tail is already tried before this empty iteration.
                     empty_exit = true
                     [nil, sequence(part, Compiler.copy(tail))]
                   else
                     [part, nil]
                   end
                 end.compact
                 options.unshift([nil, tail]) if lazy?
                 options.push([nil, tail]) unless lazy? || empty_exit
                 eliminate_self_loops(options.reject { |_, exit| exit && failing?(exit) })
               end
      @memo[state] = result
      Compiler.copy(result)
    end

    # Ordered transitions must have one contiguous block of self-loops. If exits
    # occur on both sides, regrouping also requires unambiguous iteration splits.
    def eliminate_self_loops(options)
      first = options.index { |loop_body, _| loop_body }
      return choose(options.map(&:last)) unless first

      last = options.rindex { |loop_body, _| loop_body }
      block = options[first..last]
      raise NotApplicable if block.any? { |_, exit| exit }
      before = options.take(first).map(&:last)
      after = options.drop(last + 1).map(&:last)
      loops = block.map(&:first)
      raise NotApplicable unless before.empty? || after.empty? || unique_words?(loops)

      body = choose(loops)
      choices = []
      choices << sequence(repeat(Compiler.copy(body), true), choose(before)) unless before.empty?
      choices << sequence(repeat(Compiler.copy(body), false), choose(after)) unless after.empty?
      choose(choices)
    end

    def iterations(state)
      paths(@body, state).reject { |part, _| failing?(part) }.map do |part, next_state|
        empty = Compiler::Analysis.new(part)[part].empty
        raise NotApplicable unless empty == :never || (@nullable_scalar && empty == :always)
        [Compiler.copy(part), next_state, empty]
      end
    end

    def paths(expression, state)
      return [[expression, state]] if expression.instance_of?(String)
      return [[expression, state]] if expression.kind == :sequence && expression.children.empty?

      updates = @analysis[expression].definitions.any? { |ref| @bits.key?(ref) }
      return [[substitute(expression, state), state]] unless updates ||
        (@nullable_scalar && @analysis[expression].empty != :never)

      case expression.kind
      when :repeat
        quantity = expression.quantity
        return [[Expression.new(:sequence), state]] if quantity.max.zero?

        if !updates && quantity.min.zero? && quantity.max != 1 && quantity.mode != :possessive &&
            @analysis[expression.children.first].empty == :never
          text = quantity.max < 0 ? '+' : "{1,#{quantity.max}}"
          text += '?' if quantity.mode == :lazy
          positive = Compiler::Quantity.from_text(text)
          consuming = Expression.new(:repeat, expression.children, quantity: positive)
          choices = [[consuming, state], [Expression.new(:sequence), state]]
          return quantity.mode == :lazy ? choices.reverse : choices
        end
        raise NotApplicable unless quantity.min.zero? && quantity.max == 1 && quantity.mode != :possessive
        present = paths(expression.children.first, state)
        absent = [[Expression.new(:sequence), state]]
        return quantity.mode == :lazy ? absent + present : present + absent
      when :choice
        return expression.children.reject { |part| part.kind == :omitted_branch }.flat_map { |part| paths(part, state) }
      when :conditional, :capture_conditional
        selected = selected_branch(expression, state)
        raise NotApplicable unless selected
        return paths(selected, state)
      end
      raise NotApplicable unless [:sequence, :group, :branch, :capture].include?(expression.kind)

      # Opening a capture clears its own participation until it closes again;
      # conditions inside it must not observe an earlier iteration as present.
      state &= ~@bits.fetch(expression.reference, 0) if expression.kind == :capture
      prefixes = [[[], state]]
      expression.children.each do |child|
        prefixes = prefixes.flat_map do |parts, previous|
          choices = paths(child, previous)
          # Distributing a later choice over a variable prefix would reorder
          # backtracking through that prefix.
          raise NotApplicable if choices.length > 1 && parts.any? { |part| word(part).nil? }
          choices.map { |part, next_state| [[*parts, part], next_state] }
        end
      end
      prefixes.map do |parts, next_state|
        next_state |= @bits.fetch(expression.reference, 0) if expression.kind == :capture
        [expression.with(children: parts, nullable: false), next_state]
      end
    end

    def substitute(expression, state)
      return expression if expression.instance_of?(String)
      state &= ~@bits.fetch(expression.reference, 0) if expression.kind == :capture

      if [:backreference, :value].include?(expression.kind) && @bits.key?(expression.reference)
        return literal(@values.fetch(expression.reference)) if present?(expression.reference, state)
        return expression.kind == :value ? Expression.new(:sequence) : failure
      elsif [:history, :multiplex].include?(expression.kind)
        references = expression.children.map(&:reference)
        if references.any? { |ref| @bits.key?(ref) }
          return substitute_candidates(expression, state)
        end
      elsif [:conditional, :capture_conditional].include?(expression.kind)
        selected = selected_branch(expression, state)
        if selected
          states = @bits.to_h { |ref, _| [ref, present?(ref, state)] }
          # Retain disabled slots for other, untracked captures in the discarded
          # branch. References to them later in the tail must still fail.
          return substitute(Compiler::Specialize.call(expression, states), state)
        end
        if expression.kind == :capture_conditional
          checks = expression.children.first
          remaining = checks.children.reject { |check| @bits.key?(check.reference) }
          if remaining.length != checks.children.length
            branches = expression.children.drop(1).map { |branch| substitute(branch, state) }
            return expression.with(children: [checks.with(children: remaining), *branches])
          end
        end
      end
      children = expression.children.map { |child| substitute(child, state) }
      children == expression.children ? expression : expression.with(children: children)
    end

    # A required prefix can supply an older value before this loop first updates
    # a capture. Fold known state values while retaining runtime selection for
    # those external occurrences; never combine independently selected values.
    def substitute_candidates(expression, state)
      raise NotApplicable unless expression.children.all? { |candidate| candidate.kind == :backreference }
      expression.children.reverse_each.reduce(nil) do |fallback, candidate|
        tracked = @bits.key?(candidate.reference)
        next fallback if tracked && !present?(candidate.reference, state)
        preferred = tracked ? literal(@values.fetch(candidate.reference)) : candidate
        next preferred unless fallback
        if expression.kind == :history
          tracked ? preferred : Expression.new(:conditional, [preferred, fallback], reference: candidate.reference)
        else
          choose([preferred, sequence(Expression.new(:negative_lookahead, [preferred]), fallback)])
        end
      end || failure
    end

    def selected_branch(expression, state)
      if expression.kind == :conditional
        references = [expression.reference]
        branches = expression.children
      else
        references = expression.children.first.children.map(&:reference)
        branches = expression.children.drop(1)
      end
      tracked = references.select { |ref| @bits.key?(ref) }
      return if tracked.empty?
      return branches[0] if tracked.any? { |ref| present?(ref, state) }
      return unless tracked.length == references.length

      branches[1] || Expression.new(:sequence)
    end

    def present?(reference, state)
      (state & @bits.fetch(reference)) != 0
    end

    def word(expression)
      Compiler::LiteralWord.call(expression)
    end

    def unique_words?(loops)
      words = loops.map { |part| word(part) }
      return false if words.any? { |w| w.nil? || w.empty? }

      characters = words.map { |w| w.each_char.map { |chr| CharacterSet.of_string(chr).case_insensitive } }
      characters.combination(2).none? do |left, right|
        left.take([left.length, right.length].min).each_with_index.all? { |set, index| !set.disjoint?(right[index]) }
      end
    end

    def failing?(expression)
      return false if expression.instance_of?(String)

      case expression.kind
      when :opaque then expression.children == ['(?!)']
      when :sequence, :group, :branch, :capture then expression.children.any? { |child| failing?(child) }
      when :choice then expression.children.all? { |child| failing?(child) }
      when :repeat then expression.quantity.min > 0 && failing?(expression.children.first)
      end || false
    end

    def literal(value)
      raise NotApplicable if value.nil?
      Expression.new(:group, [value])
    end

    def sequence(*children)
      Expression.new(:sequence, children)
    end

    def choose(children)
      return failure if children.empty?
      return children.first if children.length == 1
      branches = children.map { |child| Expression.new(:branch, [child]) }
      Expression.new(:group, [Expression.new(:choice, branches)])
    end

    def repeat(body, lazy)
      quantity = Compiler::Quantity.from_text(lazy ? '*?' : '*')
      Expression.new(:repeat, [Expression.new(:group, [body])], quantity: quantity)
    end

    def lazy?
      @quantity.mode == :lazy
    end

    def failure
      Expression.new(:opaque, ['(?!)'])
    end
  end
end
