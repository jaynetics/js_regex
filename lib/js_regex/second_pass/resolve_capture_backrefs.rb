# frozen_string_literal: true

class JsRegex::SecondPass::ResolveCaptureBackrefs < JsRegex::SecondPass
  def call
    walk(trace: true) do |node, event|
      if node.type == :captured_group && event == :exit
        completed[node.reference] = true
      elsif node.type == :capture_backref && event == :enter
        references = node.children.select { |backref| completed[backref.reference] }
        if references.empty?
          node.update(type: :plain, children: ['(?!)'])
        elsif !optional_groups.include?(references.first.reference)
          node.update(type: :plain, children: [references.first])
        else
          branches = []
          absent_checks = []
          references.each do |backref|
            branches << '|' unless branches.empty?
            branches << Node.new(*absent_checks, capture_check(backref.reference, true), backref)
            absent_checks = absent_checks + [capture_check(backref.reference, false)]
            break unless optional_groups.include?(backref.reference)
          end
          node.update(type: :plain, children: ['(?:', *branches, ')'])
        end
      end
    end
  end

  def completed
    @completed ||= {}
  end

  def optional_groups
    @optional_groups ||= potentially_absent_groups
  end
end
