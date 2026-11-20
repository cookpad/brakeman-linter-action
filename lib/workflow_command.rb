# frozen_string_literal: true

# https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands
module WorkflowCommand
  def self.build(command, message)
    "::#{command}::#{escape(message)}"
  end

  def self.escape(message)
    message.to_s.gsub("%", "%25").gsub("\r", "%0D").gsub("\n", "%0A")
  end
end
