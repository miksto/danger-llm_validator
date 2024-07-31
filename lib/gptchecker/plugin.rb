# frozen_string_literal: true

require "openai"
require "git"

module Danger
  class DangerGptchecker < Plugin
    attr_accessor :checks, :llm_model, :temperature, :prompt_template

    def configure_api(&block)
      OpenAI.configure(&block)
    end

    def check
      check_annotated_hunks
    end

    def check_annotated_hunks
      git.diff.each do |diff_file|
        hunks = diff_file.patch.split(/^@@/).reject(&:empty?).map { |hunk| "@@#{hunk}" }.drop(1)

        hunks_for_review = []

        prefixed_file_content = prefix_modified_lines_line_number_only(diff_file.path)
        context_extra = 10
        hunks.each do |hunk|
          parsed_header = parse_diff_header(hunk.lines.first)
          hunk_start = [(parsed_header[:new_start] - 1 - context_extra), 0].max
          hunk_end = [(parsed_header[:new_end] - 1 + context_extra), (prefixed_file_content.lines.count - 1)].min

          hunk_to_review = prefixed_file_content.lines[hunk_start..hunk_end]
          hunks_for_review << hunk_to_review.join
        end

        hunks_for_review.each do |hunk|
          check_annotated_hunk_content(diff_file.path, hunk)
        end
      end
    end

    def check_annotated_files
      git = Git.open('/Users/miksto/project/danger-openai-plugin')
      diff_files = git.diff

      modified_lines = {}
      diff_files.each do |diff_file|
        file_name = diff_file.path
        modified_lines[file_name] = get_modified_lines_for_diff_file(diff_file)
      end

      # Output the modified lines per file
      modified_lines.each do |file, lines|
        puts "File: #{file}, Modified Lines: #{lines}"
      end

      diff_files.each do |diff_file|
        file_path = diff_file.path
        annotated_file_content = prefix_modified_lines(file_path, modified_lines[file_path])
        check_annotated_file_content(file_path, annotated_file_content)
      end
    end

    def check_files
      (git.added_files + git.modified_files).each do |file|
        check_file(file)
      end
    end

    def check_hunks
      git = Git.open('/Users/miksto/project/danger-openai-plugin')
      # Iterate over each file in the diff
      git.diff.each do |diff_file|
        next unless diff_file.path.end_with?(".kt")

        diff_content = diff_file.patch

        # Split the diff content into individual hunks
        hunks = diff_content.split(/^@@/).reject(&:empty?).map { |hunk| "@@#{hunk}" }.drop(1)

        hunks.each do |hunk|
          puts "--------------------------------------------------------------------------------------------"
          puts check_hunk(hunk, diff_file)
          puts "--------------------------------------------------------------------------------------------"
        end
      end
    end

    def check_hunk(hunk, diff_file)

      messages = [
        {
          role: "system",
          content:
            "You are an expert coder who performs code reviews of a pull request in GitHub.\n" \
              "Your task is to ensure that the following #{checks.count} rules or tasks are adhered to\n" +
              checks.map.with_index(1) { |line, index| "  #{index}. #{line}" }.join("\n") + "\n\n" \
              "You should review the content between HUNK_CONTENT_BEGIN and HUNK_CONTENT_END, but may draw conclusions based on the content between METADATA_BEGIN and METADATA_EN.\n" \
              "Keep in mind that the provided hunk content is in the unified diff format, and pay attention to what the code will look like after the PR would be merged.\n" \
              "You must respond according to this JSON format:\n" \
              "{\n" +
              "  \"comments\": [\n" +
              "    { \n" +
              "      \"line_number\": 1, \n" +
              "      \"line_content\": \"line content\", \n" +
              "      \"comment\": \"desciption of issue and suggested fix\" }\n" +
              "  ]\n" +
              "}\n" +
              "However, if no issues are found respond with an empty issues array.\n" \
        },
        {
          role: "user",
          content: "METADATA_BEGIN\nfile_path: #{diff_file.path}\nLanguage: Ruby\nMETADATA_END\nHUNK_CONTENT_BEGIN\n#{hunk}\nHUNK_CONTENT_END"
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

    def check_annotated_hunk_content(file_path, hunk_content)
      messages = [
        {
          role: "system",
          content:
            "You are an expert coder who performs code reviews of a pull request in GitHub.\n" \
              "Your task is to ensure that the following #{checks.count} rules or tasks are adhered to\n" +
              checks.map.with_index(1) { |line, index| "  #{index}. #{line}" }.join("\n") + "\n\n" \
              "Each line between HUNK_CONTENT_BEGIN and HUNK_CONTENT_END is prefixed with the line number.\n" \
              "You must respond according to this JSON format:\n" \
              "{\n" +
              "  \"comments\": [\n" +
              "    { \n" +
              "      \"line_number\": 1, \n" +
              "      \"line_content\": \"line content\", \n" +
              "      \"comment\": \"desciption of issue and suggested fix\" }\n" +
              "  ]\n" +
              "}\n" +
              "However, if no issues are found respond with an empty issues array.\n" \
        },
        {
          role: "user",
          content: "METADATA_BEGIN\nfile_path: #{file_path}\nMETADATA_END\nHUNK_CONTENT_BEGIN\n#{hunk_content}\nHUNK_CONTENT_END\n"
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

    def check_annotated_file_content(file_path, file_content)
      messages = [
        {
          role: "system",
          content:
            "You are an expert coder who performs code reviews of a pull request in GitHub.\n" \
              "Your task is to ensure that the following #{checks.count} rules or tasks are adhered to\n" +
              checks.map.with_index(1) { |line, index| "  #{index}. #{line}" }.join("\n") + "\n\n" \
              "You must ONLY review lines labeled modified. Never comment on lines labeled not_modified\n" \
              "You must respond according to this JSON format:\n" \
              "{\n" +
              "  \"comments\": [\n" +
              "    { \n" +
              "      \"line_number\": 1, \n" +
              "      \"line_content\": \"line content\", \n" +
              "      \"comment\": \"desciption of issue and suggested fix\" }\n" +
              "  ]\n" +
              "}\n" +
              "However, if no issues are found respond with an empty issues array.\n" \
        },
        {
          role: "user",
          content: "METADATA_BEGIN\nfile_path: #{file_path}\nMETADATA_END\nFILE_CONTENT_BEGIN\n#{file_content}\nFILE_CONTENT_END"
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
              "You must respond according to this JSON format:\n" \
              "{\n" +
              "  \"comments\": [\n" +
              "    { \n" +
              "      \"line_number\": 1, \n" +
              "      \"line_content\": \"line content\", \n" +
              "      \"comment\": \"desciption of issue and suggested fix\" }\n" +
              "  ]\n" +
              "}\n" +
              "However, if no issues are found respond with an empty issues array.\n" \
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

    private

    # Returns an array of line numbers for all lines included in a git diff shunk
    def get_modified_lines_for_diff_file(diff_file)
      modified_lines = []
      diff_headers = diff_file.patch.lines.select { |line| line.start_with?('@@') }
      diff_headers.each do |header|
        result = parse_diff_header(header)
        unless result.nil?
          new_modified_lines = (result[:new_start]...(result[:new_start] + result[:new_count])).to_a
          modified_lines.concat(new_modified_lines)
        end
      end
      modified_lines
    end

    def parse_diff_header(header)
      # Regular expression to match the unified diff header
      match = header.match(/@@ -(\d+),?(\d+)? \+(\d+),?(\d+)? @@/)

      if match
        original_start = match[1].to_i
        original_count = match[2] ? match[2].to_i : 1
        new_start = match[3].to_i
        new_count = match[4] ? match[4].to_i : 1

        {
          original_start: original_start,
          original_end: original_start + original_count,
          original_count: original_count,
          new_start: new_start,
          new_end: new_start + new_count,
          new_count: new_count
        }
      end
    end

    # Function to build a new array of file content with prefixes
    def prefix_modified_lines(file_path, modified_lines)
      prefixed_content = []

      File.foreach(file_path).with_index(1) do |line, line_number|
        if modified_lines.include?(line_number)
          prefixed_content << "#{line_number}, modified, #{line}"
        else
          prefixed_content << "#{line_number}, not_modified, #{line}"
        end
      end
      prefixed_content.join
    end

    # Function to build a new array of file content with line number prefixes
    def prefix_modified_lines_line_number_only(file_path)
      prefixed_content = []

      File.foreach(file_path).with_index(1) do |line, line_number|
        prefixed_content << "#{line_number}: #{line}"
      end
      prefixed_content.join
    end

    def target_files(changed_files)
      changed_files.select do |file|
        file.end_with?(".kt") or file.end_with?(".ts") or file.end_with?(".js")
      end
    end
  end
end
