# frozen_string_literal: true

require "openai"
require "git"

module Danger
  # Write rules in natural language, and let an LLM ensure they are followed.
  # You can either run the LLM locally, such as with Ollama, or use one of the OpenAI models.
  #
  # @example Basic setup using gpt-4o-mini from OpenAI as the LLM
  #          llm_validator.configure_api do |config|
  #            config.access_token = ENV.fetch("OPENAI_ACCESS_TOKEN")
  #          end
  #          llm_validator.llm_model = "gpt-4o-mini"
  #          llm_validator.checks = ["Comments in the code do not state obviously incorrect things"]
  #          llm_validator.check
  #
  # @example Basic setup using a locally running LLM served by Ollama
  #          llm_validator.configure_api do |config|
  #             config.uri_base = "http://127.0.0.1:11434"
  #          end
  #          llm_validator.checks = ["Comments in the code do not state obviously incorrect things"]
  #          llm_validator.llm_model = "llama3"
  #          llm_validator.check
  #
  # @example To filter what files are included or excluded from validation
  #          llm_validator.include_patterns = ["*.kt"]
  #          llm_validator.exclude_patterns = ["src/**/*.rb"]
  #
  # @see miksto/danger-llm_validator
  # @tags validation, chatgpt, llm, openai
  class DangerLlmValidator < Plugin
    # List of checks for the LLM to validate the code changes against.
    #
    # @return [Array<String>]
    attr_accessor :checks

    # The identifier of the language model to use for validation.
    #
    # @return [String]
    attr_accessor :llm_model

    # The temperature setting for the language model, controlling the randomness of the output.
    # A lower value results in more deterministic output, while a higher value allows for more creativity.
    #
    # @return [Float]
    attr_accessor :temperature

    # The number of additional context lines to include around each change in a diff.
    # This can help the model understand the context of the changes better.
    #
    # @return [Integer]
    attr_accessor :diff_context_extra_lines

    # A list glob patterns for files to include in the validation
    #
    # @return [Array<String>]
    attr_accessor :include_patterns

    # A list glob patterns for files to exclude from the validation.
    #
    # @return [Array<String>]
    attr_accessor :exclude_patterns

    def initialize(dangerfile)
      super(dangerfile)
      @diff_context_extra_lines = 5
      @temperature = 0.0
      @include_patterns = []
      @exclude_patterns = []
    end

    # Configure the OpenAI library to connect to the desired API endpoints etc.
    # See https://github.com/alexrudall/ruby-openai for more details on what parameters can be configured.
    # @return [void]
    def configure_api(&block)
      LlmPrompter.configure(&block)
    end

    # Run the validation
    # @return [void]
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
        puts "processing: #{file_content.file_path}"
        file_content.hunks.each do |hunk|
          prompt_messages = prompt_builder.build_prompt_messages(file_path: file_content.file_path, hunk: hunk)
          llm_response = llm_prompter.chat(prompt_messages)
          unless llm_response.nil?
            apply_comments(file_path: file_content.file_path, comments: llm_response.comments)
          end
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
