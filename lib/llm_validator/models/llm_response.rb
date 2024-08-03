# frozen_string_literal: true

require "json"

module Danger
  class LlmResponse
    # The path of the file for which the validation was performed
    #
    # @return [String]
    attr_reader :file_path

    # The parsed comments from the LLM response
    #
    # @return [LlmResponseComment]
    attr_reader :comments

    # The messages that submitted to the LLM
    #
    # @return [Array<Hash{role: String, content: String}>]
    attr_reader :prompt_messages

    # The raw response from the LLM
    #
    # @return [String]
    attr_reader :raw_response

    def initialize(file_path:, prompt_messages:, comments:, raw_response:)
      @file_path = file_path
      @prompt_messages = prompt_messages
      @comments = comments
      @raw_response = raw_response
    end

    def self.from_llm_response(file_path:, prompt_messages:, llm_response:)
      parsed_data = JSON.parse(llm_response)
      comments = parsed_data["comments"].map { |comment| LlmResponseComment.from_llm_response(comment: comment) }
      LlmResponse.new(file_path: file_path, prompt_messages: prompt_messages, comments: comments, raw_response: llm_response)
    end
  end

  class LlmResponseComment
    attr_reader :line_number, :line_content, :comment

    def initialize(line_number:, line_content:, comment:)
      @line_number = line_number
      @line_content = line_content
      @comment = comment
    end

    def self.from_llm_response(comment:)
      LlmResponseComment.new(
        line_number: comment["line_number"].to_i,
        line_content: comment["line_content"],
        comment: comment["comment"]
      )
    end
  end
end
