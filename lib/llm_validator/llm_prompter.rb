# frozen_string_literal: true

module Danger
  class LlmPrompter
    attr_reader :client, :llm_model, :temperature
    private :client

    def initialize(llm_model:, temperature:)
      @client = OpenAI::Client.new
      @llm_model = llm_model
      @temperature = temperature
    end

    def self.configure(&block)
      OpenAI.configure(&block)
    end

    def chat(messages)
      response = client.chat(
        parameters: {
          model: llm_model,
          response_format: { type: "json_object" },
          messages: messages,
          temperature: temperature
        }
      )
      LlmResponse.from_json(response.dig("choices", 0, "message", "content"))
    end
  end
end
