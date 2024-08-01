# frozen_string_literal: true

module Danger
  class PromptBuilder
    attr_reader :checks, :pre_checks_content, :post_checks_content

    def initialize(checks)
      @checks = checks
      @pre_checks_content = "You are an expert coder who performs code reviews of a pull request in GitHub.\n" \
        "Your task is to ensure that the following statements are adhered to:"
      @post_checks_content = "However, if no issues are found, respond with an empty array.\n" \
        "Each line between CONTENT_BEGIN and CONTENT_END is prefixed with the line number."
    end

    def build_prompt_messages(file_path:, hunk:)
      [
        {
          role: "system",
          content: build_system_content
        },
        {
          role: "user",
          content: build_user_content(file_path: file_path, hunk: hunk)
        }
      ]
    end

    private

    def build_system_content
      "#{pre_checks_content}\n" \
        "#{checks.map.with_index(1) { |check, index| "  #{index}. #{check}" }.join("\n")}\n\n" \
        "#{post_checks_content}\n" \
        "You must respond according to this JSON format:\n" \
        "{\n" \
        "  \"comments\": [\n" \
        "    {\n" \
        "      \"line_number\": 1,\n" \
        "      \"line_content\": \"line content\",\n" \
        "      \"comment\": \"description of issue and suggested fix\"\n" \
        "    }\n" \
        "  ]\n" \
        "}"
    end

    def build_user_content(file_path:, hunk:)
      "METADATA_BEGIN\nfile_path : #{file_path}\nMETADATA_END\nCONTENT_BEGIN\n#{hunk}\nCONTENT_END\n"
    end

  end
end
