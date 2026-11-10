# frozen_string_literal: true

require_relative 'model'

class JsRegex::SecondPass::Compiler::Analysis
  Summary = Struct.new(:definitions, :references, :must_capture, :may_capture, :empty, :entry_reads, keyword_init: true)

  attr_reader :captures, :value_uses, :presence_uses, :optional_captures,
              :bounded_capture_loops, :unbounded_capture_loops, :nullable_order_loops

  def initialize(expression)
    @summaries = {}
    @required_references = {}
    @captures = {}
    @optional_captures = false
    @bounded_capture_loops = false
    @unbounded_capture_loops = false
    @nullable_order_loops = false
    @nullable_optionals = nil
    @value_uses = Hash.new { |hash, key| hash[key] = [] }
    @presence_uses = Hash.new { |hash, key| hash[key] = [] }
    @root = summarize(expression)
    if @nullable_optionals
      @nullable_order_loops ||= @nullable_optionals.any? do |definitions|
        definitions.all? { |reference| @root.references.fetch(reference, 0).zero? }
      end
    end
    [@value_uses, @presence_uses].each do |uses|
      uses.each_value(&:freeze)
      uses.default_proc = nil
      uses.freeze
    end
    @captures.freeze
    @summaries.freeze
  end

  def [](expression)
    @summaries.fetch(expression)
  end

  # A region can be copied only when every reference to its captures stays
  # inside it. Compose existing summaries instead of reanalyzing a wrapper tree.
  def closed?(parts)
    summaries = parts.map { |part| self[part] }
    summaries.flat_map(&:definitions).uniq.all? do |reference|
      summaries.sum { |summary| summary.references.fetch(reference, 0) } == @root.references.fetch(reference, 0)
    end
  end

  # Computed only when requested. Required value reads constrain participation;
  # value checks, absent branches, and negative assertions do not.
  def required_references(expression)
    return [] if expression.instance_of?(String)
    return @required_references[expression] if @required_references.key?(expression)
    @required_references[expression] = required_reads(expression).freeze
  end

  private

  def required_reads(expression)
    case expression.kind
    when :backreference then [expression.reference]
    when :value, :negative_lookahead, :negative_lookbehind, :absence, :dropped, :omitted_branch, :opaque then []
    when :repeat, :native_repeat
      expression.quantity.min.zero? ? [] : required_references(expression.children.first)
    when :choice, :conditional, :capture_conditional, :history, :multiplex
      branches = expression.kind == :capture_conditional ? expression.children.drop(1) : expression.children
      return [] if [:conditional, :capture_conditional].include?(expression.kind) && branches.length < 2
      branches.map { |child| required_references(child) }.reduce { |left, right| left & right } || []
    else
      expression.children.flat_map { |child| required_references(child) }.uniq
    end
  end

  def summarize(expression)
    return @summaries[expression] if @summaries.key?(expression)

    if expression.instance_of?(String)
      empty = if expression.empty?
                :always
              elsif expression.each_char.none? { |character| '\\.^$|?*+()[]{}'.include?(character) }
                :never # A plain literal fragment consumes at least one character.
              else
                :unknown
              end
      return store(expression, [], {}, [], [], empty)
    end

    children = expression.children.map { |child| summarize(child) }
    definitions = children.flat_map(&:definitions).uniq
    references = Hash.new(0)
    children.each { |child| child.references.each { |reference, count| references[reference] += count } }
    may = children.flat_map(&:may_capture).uniq
    must = children.flat_map(&:must_capture).uniq

    case expression.kind
    when :capture
      @captures[expression.reference] = expression
      definitions.unshift(expression.reference)
      may.unshift(expression.reference)
      must.unshift(expression.reference)
    when :choice, :conditional, :capture_conditional
      alternatives = children
      if expression.kind == :choice
        alternatives = expression.children.zip(children).reject { |part, _| part.kind == :omitted_branch }.map(&:last)
      elsif expression.kind == :capture_conditional
        alternatives = children.drop(1)
      end
      must = alternatives.map(&:must_capture).reduce { |left, right| left & right } || []
      # A missing else branch is an implicit empty alternative.
      must = [] if expression.kind != :choice && alternatives.length < 2
    when :repeat, :native_repeat
      must = [] if expression.quantity.min.zero?
      may = [] if expression.quantity.max.zero?
      if expression.kind == :repeat && children.first.empty == :always && expression.quantity.max != 0
        @nullable_order_loops ||= definitions.empty? && references.empty?
        if definitions.any? && expression.quantity.min.zero? && expression.quantity.max == 1
          (@nullable_optionals ||= []) << definitions
        end
      end
      unless definitions.empty?
        @optional_captures ||= expression.quantity.min.zero? && expression.quantity.max == 1
        @bounded_capture_loops ||= expression.quantity.max > 1
        @unbounded_capture_loops ||= expression.quantity.max < 0
      end
    when :negative_lookahead, :negative_lookbehind, :absence, :dropped, :omitted_branch
      may = must = []
    when :opaque
      must = [] # Compound fragments require their own participation analysis.
    end

    if expression.reference && expression.kind != :capture
      references[expression.reference] += 1
      uses = [:conditional, :sequence].include?(expression.kind) ? @presence_uses : @value_uses
      uses[expression.reference] << expression
    end
    store(expression, definitions, references, must, may, empty_fact(expression, children), entry_reads(expression, children))
  end

  # Reads not preceded by a mandatory update in this subtree may observe an
  # earlier iteration. Alternatives cannot borrow updates from another arm.
  def entry_reads(expression, children)
    if [:choice, :conditional, :capture_conditional, :opaque].include?(expression.kind)
      reads = children.flat_map(&:entry_reads)
    else
      present = []
      reads = children.flat_map do |child|
        needed = child.entry_reads - present
        present |= child.must_capture
        needed
      end
    end
    reads << expression.reference if expression.reference && expression.kind != :capture
    reads.uniq.freeze
  end

  # :always means unconditional empty matching, :never excludes empty matching,
  # and :unknown includes assertions and opaque regex fragments. No reparsing.
  def empty_fact(expression, children)
    return :never if expression.nonempty
    return :always if expression.nullable

    case expression.kind
    when :repeat, :native_repeat
      expression.quantity.min.zero? ? :always : children.first.empty
    when :sequence, :branch, :group, :capture
      return :never if children.any? { |child| child.empty == :never }
      children.all? { |child| child.empty == :always } ? :always : :unknown
    when :choice
      alternatives = expression.children.zip(children).reject { |part, _| part.kind == :omitted_branch }.map(&:last)
      return :always if alternatives.empty? || alternatives.any? { |child| child.empty == :always }
      alternatives.all? { |child| child.empty == :never } ? :never : :unknown
    when :conditional, :capture_conditional
      alternatives = expression.kind == :conditional ? children : children.drop(1)
      alternatives.length == 2 && alternatives.all? { |child| child.empty == :never } ? :never : :unknown
    when :atomic
      children.first.empty # The lookahead captures exactly the value consumed.
    when :dropped, :omitted_branch, :keep, :absence
      :always
    else
      :unknown
    end
  end

  def store(expression, definitions, references, must, may, empty, entry_reads = [])
    @summaries[expression] = Summary.new(definitions: definitions.freeze, references: references.freeze,
                                          must_capture: must.freeze, may_capture: may.freeze,
                                          empty: empty, entry_reads: entry_reads.freeze).freeze
  end
end
