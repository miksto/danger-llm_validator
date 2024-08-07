# frozen_string_literal: true

module Danger
  class PromptBuilder
    attr_reader :checks, :system_prompt_template, :user_prompt_template

    def initialize(checks:, system_prompt_template:, user_prompt_template:)
      @checks = checks
      @system_prompt_template = system_prompt_template
      @user_prompt_template = user_prompt_template
    end

    def build_prompt_messages(file_path:, content:)
      messages = []
      unless system_prompt_template.nil?
        messages <<
          {
            role: "system",
            content: build_system_content(file_path: file_path, content: content)
          }
      end

      unless user_prompt_template.nil?
        messages << {
          role: "user",
          content: build_user_content(file_path: file_path, content: content)
        }
      end

      messages
    end

    private

    JSON_FORMAT = "{\n  " \
                  "\"comments\": [\n    " \
                  "{\n      " \
                  "\"line_number\": 1,\n      " \
                  "\"line_content\": \"line content\",\n      " \
                  "\"comment\": \"description of issue and suggested fix\"\n    " \
                  "}\n  " \
                  "]\n" \
                  "}"

    def replace_placeholders(template:, file_path:, content:)
      checks_string = checks.map.with_index(1) { |check, index| "  #{index}. #{check}" }.join("\n")
      template.gsub("{{CHECKS}}", checks_string)
        .gsub("{{JSON_FORMAT}}", JSON_FORMAT)
        .gsub("{{FILE_PATH}}", file_path)
        .gsub("{{CONTENT}}", content)
    end

    def build_system_content(file_path:, content:)
      replace_placeholders(template: system_prompt_template, file_path: file_path, content: content)
    end

    def build_user_content(file_path:, content:)
      replace_placeholders(template: user_prompt_template, file_path: file_path, content: content)
    end
  end
end
