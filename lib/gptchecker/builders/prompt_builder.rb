# frozen_string_literal: true

class PromptBuilder
  attr_reader :checks, :file_path, :file_content

  def initialize(checks, file_content)
    @checks = checks
    @file_content = file_content
  end

  def build_prompt_messages
    [
      {
        role: "system",
        content: build_system_content
      },
      {
        role: "user",
        content: build_user_content
      }
    ]
  end

  private

  def build_system_content
    "You are an expert coder who performs code reviews of a pull request in GitHub.\n" \
      "Your task is to ensure that the following #{checks.count} rules or tasks are adhered to:\n" +
      checks.map.with_index(1) { |check, index| "  #{index}. #{check}" }.join("\n") + "\n\n" \
      "However, if no issues are found, respond with an empty comments array.\n" \
      "Each line between CONTENT_BEGIN and CONTENT_END is prefixed with the line number.\n" \
      "You must respond according to this JSON format:\n" \
      "{\n" \
      "  \"comments\": [\n" \
      "    { \n" \
      "      \"line_number\": 1, \n" \
      "      \"line_content\": \"line content\", \n" \
      "      \"comment\": \"description of issue and suggested fix\" }\n" \
      "  ]\n" \
      "}\n"
  end

  def build_user_content
    "METADATA_BEGIN\nfile_path: #{file_content.file_path}\nMETADATA_END\nCONTENT_BEGIN\n#{file_content.content}\nCONTENT_END\n"
  end

end
