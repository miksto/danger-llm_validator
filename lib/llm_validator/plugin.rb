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
  #          llm_validator.checks = ["Comments in the code do not state obviously incorrect things"]
  #          llm_validator.llm_model = "gpt-4o-mini"
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
    # An array of checks for the LLM to validate the code changes against.
    #
    # @return [Array<String>]
    attr_accessor :checks

    # The identifier of the language model to use for validation.
    #
    # @return [String]
    attr_accessor :llm_model

    # The temperature setting for the language model, controlling the randomness of the output.
    # A lower value results in more deterministic output, while a higher value allows for more creativity.
    # Defaults to 0.0 for a deterministic output.
    #
    # @return [Float]
    attr_accessor :temperature

    # The number of additional context lines to include around each change in a diff. This is in addition
    # to the context lines included by the default git dif.
    # This can help the model understand the context of the changes better.
    # The default value is 5.
    #
    # @return [Integer]
    attr_accessor :diff_context_extra_lines

    # An array of glob patterns for files to include in the validation.
    #
    # @return [Array<String>]
    attr_accessor :include_patterns

    # An array of glob patterns for files to exclude from the validation.
    #
    # @return [Array<String>]
    attr_accessor :exclude_patterns

    # An array of all LLM responses that were received during validation.
    # Includes extra data such as file paths and the prompt supplied to the LLM as well as the raw response from the LLM.
    #
    # @return [Array<LlmResponse>]
    attr_accessor :llm_responses

    # An array debug messages for any error that occurred during validation.
    #
    # @return [Array<String>]
    attr_accessor :validation_errors

    # Whether a warning should be posted if any of the validations resulted in an error. Defaults to true.
    #
    # @return [Boolean]
    attr_accessor :warn_for_validation_errors

    # Whether a warning should be posted for comments received from the LLM. Defaults to true.
    #
    # @return [Boolean]
    attr_accessor :warn_for_llm_comments

    # Allows you to customize the system prompt for the LLM. Typically used to set overall behavior, tone, and rules for how the AI model.
    # Supported place holders are `{{CHECKS}}`, `{{JSON_FORMAT}}`, `{{FILE_PATH}}` and `{{CONTENT}}`.
    #
    # @return [String]
    attr_accessor :system_prompt_template

    # Allows you to customize the user prompt for the LLM. Typically used to provide a specific input or question to the AI.
    # Supported place holders are `{{CHECKS}}`, `{{JSON_FORMAT}}`, `{{FILE_PATH}}` and `{{CONTENT}}`.
    #
    # @return [String]
    attr_accessor :user_prompt_template

    DEFAULT_SYSTEM_PROMPT_TEMPLATE = "You are an expert coder who performs code reviews of a pull request in GitHub.\n" \
                                     "Your ONLY task is to ensure that the following statements are adhered to:\n" \
                                     "{{CHECKS}}\n\n" \
                                     "If no violations are found, respond with an empty comments array.\n" \
                                     "Each line between CONTENT_BEGIN and CONTENT_END is prefixed with the line number.\n" \
                                     "You must respond with this JSON format:\n" \
                                     "{{JSON_FORMAT}}\n"

    DEFAULT_USER_PROMPT_TEMPLATE = "METADATA_BEGIN\nfile_path: {{FILE_PATH}}\nMETADATA_END\nCONTENT_BEGIN\n{{CONTENT}}CONTENT_END\n"

    def initialize(dangerfile)
      super
      @diff_context_extra_lines = 5
      @temperature = 0.0
      @include_patterns = []
      @exclude_patterns = []
      @warn_for_validation_errors = true
      @warn_for_llm_comments = true
      @system_prompt_template = DEFAULT_SYSTEM_PROMPT_TEMPLATE
      @user_prompt_template = DEFAULT_USER_PROMPT_TEMPLATE
    end

    # Configure the OpenAI library to connect to the desired API endpoints etc.
    # See https://github.com/alexrudall/ruby-openai for more details on what parameters can be configured.
    # @return [void]
    def configure_api(&block)
      LlmPrompter.configure(&block)
    end

    # Run the validation. Loops over all hunks in the git diff, and prompts the LLM to validate it.
    # Creates warnings for all comments received from the LLM.
    # @return [void]
    def check
      self.llm_responses = []
      self.validation_errors = []

      file_filter = FileFilter.new(include_patterns: include_patterns, exclude_patterns: exclude_patterns)
      hunk_content_list = HunkContentBuilder.new(
        git: git,
        file_filter: file_filter,
        diff_context_extra_lines: diff_context_extra_lines
      ).build_file_contents
      prompt_builder = PromptBuilder.new(
        checks: checks,
        system_prompt_template: system_prompt_template,
        user_prompt_template: user_prompt_template
      )
      llm_prompter = LlmPrompter.new(llm_model: llm_model, temperature: temperature)

      hunk_content_list.each do |file_content|
        file_content.hunks.each do |hunk|
          prompt_messages = prompt_builder.build_prompt_messages(file_path: file_content.file_path, content: hunk)
          begin
            llm_response_text = llm_prompter.chat(prompt_messages)
            llm_response = LlmResponse.from_llm_response(
              file_path: file_content.file_path,
              prompt_messages: prompt_messages,
              llm_response: llm_response_text
            )

            self.llm_responses << llm_response
            if warn_for_llm_comments
              warn_for_comments(file_path: file_content.file_path, comments: llm_response.comments)
            end
          rescue StandardError => e
            validation_errors << "Failed to validate file: #{file_content.file_path} with error: #{e}. LLM response: '#{llm_response_text}'"
          end
        end
      end

      if warn_for_validation_errors && !validation_errors.empty?
        warn(validation_errors.join("\n\n"))
      end
    end

    private

    def warn_for_comments(file_path:, comments:)
      comments.each do |comment|
        warn(
          comment.comment,
          file: file_path,
          line: comment.line_number
        )
      end
    end
  end
end
