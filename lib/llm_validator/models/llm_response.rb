# frozen_string_literal: true

require "json"

module Danger
  class LlmResponse
    attr_reader :comments

    def initialize(comments)
      @comments = comments
    end

    def self.from_json(json)
      parsed_data = JSON.parse(json)
      comments = parsed_data["comments"].map do |comment_data|
        LlmResponseComment.new(
          line_number: comment_data["line_number"],
          line_content: comment_data["line_content"],
          comment: comment_data["comment"]
        )
      end
      new(comments)
    end
  end

  class LlmResponseComment
    attr_reader :line_number, :line_content, :comment

    def initialize(line_number:, line_content:, comment:)
      @line_number = line_number
      @line_content = line_content
      @comment = comment
    end
  end
end
