# frozen_string_literal: true

require File.expand_path("spec_helper", __dir__)

module Danger
  describe Danger::DangerLlmValidator do
    it "should be a plugin" do
      expect(Danger::DangerLlmValidator.new(nil)).to be_a Danger::Plugin
    end

    describe "with Dangerfile" do
      before do
        @dangerfile = testing_dangerfile
        @my_plugin = @dangerfile.llm_validator

        use_open_ai = false
        if use_open_ai
          @my_plugin.llm_model = "gpt-4o-mini"
        else
          @my_plugin.llm_model = "llama3"
        end

        @my_plugin.temperature = 0.0

        @my_plugin.configure_api do |config|
          if use_open_ai
            config.access_token = ENV.fetch("OPENAI_ACCESS_TOKEN")
          else
            config.uri_base = "http://127.0.0.1:11434"
          end
          config.log_errors = true # Highly recommended in development, so you can see what errors OpenAI is returning. Not recommended in production because it could leak private data to your logs.
        end

        # mock the PR data
        # you can then use this, eg. github.pr_author, later in the spec
        #json = File.read("#{File.dirname(__FILE__)}/support/fixtures/github_pr.json") # example json: `curl https://api.github.com/repos/danger/danger-plugin-template/pulls/18 > github_pr.json`
        #allow(@my_plugin.github).to receive(:pr_json).and_return(json)
      end


      it "Check erroneous file" do
        allow_any_instance_of(Danger::DangerfileGitPlugin).to receive(:added_files).and_return(["src/main/kotlin/com/llmvalidator/plugin/HelloWorld.kt"])
        allow_any_instance_of(Danger::DangerfileGitPlugin).to receive(:modified_files).and_return([])
        file_content = File.readlines("spec/support/fixtures/HelloWorldWithErrors.kt")
        allow(File).to receive(:readlines).and_return(file_content)

        @my_plugin.checks = [
          "Comments match what the code actually does",
          "Variable names match the content they are assigned"
        ]

        @my_plugin.check_files
      end

      it "Check correct file" do
        git = Git.open('/Users/miksto/project/danger-openai-plugin')
        diff = git.diff

        allow_any_instance_of(Danger::DangerfileGitPlugin).to receive(:diff).and_return(diff)
        allow_any_instance_of(Danger::DangerfileGitPlugin).to receive(:added_files).and_return(["src/main/kotlin/com/llmvalidator/plugin/HelloWorld.kt"])
        allow_any_instance_of(Danger::DangerfileGitPlugin).to receive(:modified_files).and_return([])
        file_content = File.readlines("spec/support/fixtures/HelloWorld2.kt")
        allow(File).to receive(:readlines).and_return(file_content)

        @my_plugin.checks = [
          "Comments match what the code actually does",
          "Variable names match the content they are assigned"
        ]
        @my_plugin.exclude_patterns = ["*.rb"]
        @my_plugin.diff_context_extra_lines = 10

        @my_plugin.check
      end

      it "It submits chunks" do
        # allow_any_instance_of(Danger::DangerfileGitPlugin).to receive(:added_files).and_return(["src/main/kotlin/com/llmvalidator/plugin/HelloWorld.kt"])
        # allow_any_instance_of(Danger::DangerfileGitPlugin).to receive(:modified_files).and_return([])
        # file_content = File.readlines("spec/support/fixtures/HelloWorld2.kt")
        # allow(File).to receive(:readlines).and_return(file_content)

        git = Git.open('/Users/miksto/project/danger-openai-plugin')
        allow_any_instance_of(Danger::DangerfileGitPlugin).to receive(:diff).and_return(nil)


        @my_plugin.checks = [
          "Comments match what the code actually does",
          "Variable names match the content they are assigned"
        ]

        @my_plugin.check
      end
    end
  end
end
