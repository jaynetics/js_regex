# frozen_string_literal: true

class JsRegex::SecondPass::ResolveCaptureConditionals < JsRegex::SecondPass
  def call
    walk do |node|
      next unless node.type == :capture_conditional

      references = node.children.first.children.map(&:reference)
      present_checks = []
      references.each do |reference|
        present_checks << '|' unless present_checks.empty?
        present_checks << capture_check(reference, true)
      end
      absent_checks = references.map { |reference| capture_check(reference, false) }
      true_branch, false_branch = node.children[1..-1]
      node.update(type: :plain, children: [
        '(?:(?:', Node.new('(?:', *present_checks, ')'), true_branch,
        ')|(?:', *absent_checks, false_branch || Node.new, '))'
      ])
    end
  end
end
