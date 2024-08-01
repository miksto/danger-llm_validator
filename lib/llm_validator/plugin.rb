# frozen_string_literal: true

require "openai"
require "git"

module Danger

  # Write rules in natural natural language and let an LLM validate the code accordingly.
  # @example Configure to use OpenAI
  #          llm_validator.configure_api do |config|
  #            config.access_token = ENV.fetch("OPENAI_ACCESS_TOKEN")
  #            config.organization_id = ENV.fetch("OPENAI_ORGANIZATION_ID") # Optional
  #            config.log_errors = true # Highly recommended in development, so you can see what errors OpenAI is returning. Not recommended in production because it could leak private data to your logs.
  #          end
  #          llm_validator.llm_model = "gpt-4o-mini"
  #          llm_validator.check
  #
  # @example Configure to use a locally running Ollama server
  #          llm_validator.configure_api do |config|
  #             config.uri_base = "http://127.0.0.1:11434"
  #          end
  #          llm_validator.llm_model = "llama3"
  #          llm_validator.check
  class DangerLlmValidator < Plugin
    # A list of checks to be performed by the validator
    #
    # @return [Array<String>]
    attr_accessor :checks

    # The identifier of the language model used for validation.
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

    # A list of file patterns to include when running the checks.
    #
    # @return [Array<String>]
    attr_accessor :include_patterns

    # A list of file patterns to exclude from validation.
    #
    # @return [Array<String>]
    attr_accessor :exclude_patterns

    attr_reader :file_filter, :llm_prompter
    private :file_filter, :llm_prompter

    def initialize(dangerfile)
      super(dangerfile)
      @diff_context_extra_lines = 5
      @temperature = 0.0
      @include_patterns = []
      @exclude_patterns = []
    end

    # Configure the OpenAI library to connect to the desired API endpoints etc.
    # See https://github.com/alexrudall/ruby-openai for more details on what parameters can be configured.
    def configure_api(&block)
      LlmPrompter.configure(&block)
    end

    # Run the validation
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
