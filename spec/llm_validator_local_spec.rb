# frozen_string_literal: true

require File.expand_path("spec_helper", __dir__)

module Danger
  describe Danger::DangerLlmValidator do
    describe "with Dangerfile" do
      before do
        @dangerfile = testing_dangerfile
        @llm_validator = @dangerfile.llm_validator
      end

      describe "with real llm_prompter implementation and local git diff" do
        before do
          git = Git.open(Dir.pwd)
          allow_any_instance_of(Danger::DangerfileGitPlugin).to receive(:diff).and_return(git.diff)

          use_open_ai = true
          if use_open_ai
            @llm_validator.llm_model = "gpt-4o-mini"
          else
            @llm_validator.llm_model = "llama3"
          end

          @llm_validator.configure_api do |config|
            if use_open_ai
              config.access_token = ENV.fetch("OPENAI_ACCESS_TOKEN")
            else
              config.uri_base = "http://127.0.0.1:11434"
            end
            config.log_errors = true
          end
        end

        it "It submits chunks" do
          @llm_validator.checks = [
            "Comments in the code do not state obviously incorrect things",
            "Variable names are not clearly misleading and incorrect"
          ]

          @llm_validator.check

          @llm_validator.validation_errors.each do |message|
            puts message
          end

          @llm_validator.llm_responses.each do |response|
            puts response.prompt_messages
            puts response.raw_response
            puts "---"
          end
        end
      end
    end
  end
end
