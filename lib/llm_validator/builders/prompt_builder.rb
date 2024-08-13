# frozen_string_literal: true

module Danger
  class PromptBuilder
    attr_reader :checks, :system_prompt_template, :user_prompt_template, :json_format

    def initialize(checks:, system_prompt_template:, user_prompt_template:, json_format:)
      @checks = checks
      @system_prompt_template = system_prompt_template
      @user_prompt_template = user_prompt_template
      @json_format = json_format
    end

    def build_prompt_messages(file_path:, content:)
      messages = []
      unless system_prompt_template.nil?
        messages <<
          {
            role: "system",
            content: build_system_content(file_path: file_path, content: content, json_format: json_format)
          }
      end

      unless user_prompt_template.nil?
        messages << {
          role: "user",
          content: build_user_content(file_path: file_path, content: content, json_format: json_format)
        }
      end

      messages
    end

    private

    def replace_placeholders(template:, file_path:, content:, json_format:)
      checks_string = checks.map.with_index(1) { |check, index| "  #{index}. #{check}" }.join("\n")
      template.gsub("{{CHECKS}}", checks_string)
        .gsub("{{JSON_FORMAT}}", json_format)
        .gsub("{{FILE_PATH}}", file_path)
        .gsub("{{CONTENT}}", content)
    end

    def build_system_content(file_path:, content:, json_format:)
      replace_placeholders(template: system_prompt_template, file_path: file_path, content: content, json_format: json_format)
    end

    def build_user_content(file_path:, content:, json_format:)
      replace_placeholders(template: user_prompt_template, file_path: file_path, content: content, json_format: json_format)
    end
  end
end
