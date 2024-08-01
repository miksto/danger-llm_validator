# frozen_string_literal: true

require "openai"
require "git"
require_relative "builders/hunk_content_builder"
require_relative "builders/prompt_builder"
require_relative "llm_prompter"
require_relative "models/file_filter"
require_relative "models/llm_response"

module Danger
  class DangerGptchecker < Plugin
    attr_accessor :checks, :llm_model, :temperature, :diff_context_extra_lines, :include_patterns, :exclude_patterns
    attr_reader :file_filter, :llm_prompter
    private :file_filter

    def initialize(dangerfile)
      super(dangerfile)
      @diff_context_extra_lines = 0
      @temperature = 0.0
      @include_patterns = []
      @exclude_patterns = []
    end

    def configure_api(&block)
      LlmPrompter.configure(&block)
    end

    def check
      file_filter = FileFilter.new(include_patterns: include_patterns, exclude_patterns: exclude_patterns)
      hunk_content_list = HunkContentBuilder.new(
        git: git,
        file_filter: file_filter,
        diff_context_extra_lines: diff_context_extra_lines
      ).build_file_contents
      prompt_builder = PromptBuilder.new(checks)
      llm_prompter = LlmPrompter.new(llm_model: llm_model, temperature: temperature)

      hunk_content_list.each do |file_content|
        file_content.hunks.each do |hunk|
          prompt_messages = prompt_builder.build_prompt_messages(file_path: file_content.file_path, hunk: hunk)
          llm_response = llm_prompter.chat(prompt_messages)
          apply_comments(file_path: file_content.file_path, comments: llm_response.comments)
        end
      end
    end

    private

    def apply_comments(file_path:, comments:)
      comments.each do |comment|
        puts "#{file_path}:#{comment.line_number} - #{comment.comment}"
        warn(
          comment.comment,
          file: file_path,
          line: comment.line_number
        )
      end
    end
  end
end
