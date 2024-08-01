# frozen_string_literal: true

require "openai"
require "git"
require_relative "models/file_filter"
require_relative "builders/prompt_builder"
require_relative "builders/hunk_content_builder"
require_relative "models/llm_response"

module Danger
  class DangerGptchecker < Plugin
    attr_accessor :checks, :llm_model, :temperature, :diff_context_extra_lines, :include_patterns, :exclude_patterns
    attr_reader :file_filter
    private :file_filter

    def initialize(dangerfile)
      super(dangerfile)
      @diff_context_extra_lines = 0
      @temperature = 0.0
      @include_patterns = []
      @exclude_patterns = []
    end

    def configure_api(&block)
      OpenAI.configure(&block)
    end

    def check
      file_filter = FileFilter.new(include_patterns: include_patterns, exclude_patterns: exclude_patterns)
      hunk_content_list = HunkContentBuilder.new(
        git: git,
        file_filter: file_filter,
        diff_context_extra_lines: diff_context_extra_lines
      ).build_file_contents
      prompt_builder = PromptBuilder.new(checks)
      hunk_content_list.each do |file_content|
        file_content.hunks.each do |hunk|
          prompt_messages = prompt_builder.build_prompt_messages(file_path: file_content.file_path, hunk: hunk)
          llm_response_text = prompt_llm(prompt_messages)
          llm_response = LlmResponse.from_json(llm_response_text)
          apply_comments(file_path: file_content.file_path, comments: llm_response.comments)
        end
      end
    end

    private

    # Returns the returned message from the LLM
    def prompt_llm(prompt_messages)
      puts prompt_messages
      client = OpenAI::Client.new

      response = client.chat(
        parameters: {
          model: llm_model,
          response_format: { type: "json_object" },
          messages: prompt_messages,
          temperature: temperature
        }
      )
      response.dig("choices", 0, "message", "content")
    end

    def apply_comments(file_path:, comments:)
      comments.each do |comment|
        puts " - #{comment.comment}"
        warn(
          comment.comment,
          file: file_path,
          line: comment.line_number
        )
      end
    end
  end
end
