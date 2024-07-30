# frozen_string_literal: true

require "openai"

module Danger
  class DangerGptchecker < Plugin
    attr_accessor :checks, :llm_model, :temperature, :prompt_template

    def configure_api(&block)
      OpenAI.configure(&block)
    end

    def check
      targets = target_files(git.added_files + git.modified_files)
      targets.each do |target|
        check_file(target)
      end
    end

    def check_file(file)
      indexed_lines = File.readlines(file).map.with_index(1) do |line, index|
        "#{index}: #{line.chomp}"
      end.join("\n")


      messages = [
        {
          role: "system",
          content:
            "You are an expert coder who performs code reviews of a pull request in GitHub.\n" \
              "Your task is to ensure that the following #{checks.count} rules or tasks are adhered to\n" +
              checks.map.with_index(1) { |line, index| "  #{index}. #{line}" }.join("\n") + "\n\n" \
              "You should review the content between FILE_CONTENT_BEGIN and FILE_CONTENT_END, but may draw conclusions based on the content between METADATA_BEGIN and METADATA_EN.\n" \
              "Each line between FILE_CONTENT_BEGIN and FILE_CONTENT_END is prefixed with the line number.\n" \
              "You must respond with a json structure adhering to this json schema:\n" \
              "{\n" +
              "    \"$schema\": \"http://json-schema.org/draft-04/schema#\",\n" +
              "    \"type\": \"object\",\n" +
              "    \"properties\": {\n" +
              "      \"comments\": {\n" +
              "        \"type\": \"array\",\n" +
              "        \"items\": [\n" +
              "          {\n" +
              "            \"type\": \"object\",\n" +
              "            \"properties\": {\n" +
              "              \"line_number\": {\n" +
              "                \"type\": \"integer\"\n" +
              "              },\n" +
              "              \"line_content\": {\n" +
              "                \"type\": \"string\"\n" +
              "              },\n" +
              "              \"comment\": {\n" +
              "                \"type\": \"string\"\n" +
              "              }\n" +
              "            },\n" +
              "            \"required\": [\n" +
              "              \"line_number\",\n" +
              "              \"line_content\",\n" +
              "              \"comment\"\n" +
              "            ]\n" +
              "          }\n" +
              "        ]\n" +
              "      }\n" +
              "    },\n" +
              "    \"required\": [\n" +
              "      \"issues\"\n" +
              "    ]\n" +
              "  }\n" +
              "However, if no issues are found, only respond with empty string.\n" \
        },
        {
          role: "user",
          content: "METADATA_BEGIN\nfile_path: #{file}\nMETADATA_END\nFILE_CONTENT_BEGIN\n#{indexed_lines}\nFILE_CONTENT_END"
        }
      ]
      puts messages
      client = OpenAI::Client.new

      response = client.chat(
        parameters: {
          model: llm_model,
          response_format: { type: "json_object" },
          messages: messages,
          temperature: temperature
        }
      )
      fixes = response.dig("choices", 0, "message", "content").split("\n")
      puts "-----------------------"
      fixes.each do |fix|
        puts(fix)
      end
      puts "-----------------------"
    end

    def target_files(changed_files)
      changed_files.select do |file|
        file.end_with?(".kt") or file.end_with?(".ts") or file.end_with?(".js")
      end
    end
  end
end
