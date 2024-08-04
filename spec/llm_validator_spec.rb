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
        @llm_validator = @dangerfile.llm_validator
      end

      describe "with simple git diff" do
        let(:mock_test_file_path) { "spec/fixtures/TestFileWithIssues.kt" }
        let(:mock_diff) { instance_double(Git::Diff) }
        let(:mock_diff_file) { instance_double(Git::Diff::DiffFile, path: mock_test_file_path, type: "modified", binary?: false) }
        let(:mock_llm_prompter) { instance_double(LlmPrompter) }
        let(:mock_diff_file_patch) { File.read("spec/fixtures/diff_file_simple_patch.txt") }
        let(:mock_llm_response_with_comments) { File.read("spec/fixtures/llm_response_with_comments.json") }
        let(:mock_llm_response_without_comments) { File.read("spec/fixtures/llm_response_without_comments.json") }
        let(:mock_patch_content_for_review) { File.read("spec/fixtures/patch_for_review.txt") }

        before do
          allow(@llm_validator.git).to receive(:diff).and_return(mock_diff)
          allow(@llm_validator).to receive(:warn)
          allow(mock_diff).to receive(:select).and_return([mock_diff_file])
          allow(mock_diff_file).to receive(:patch).and_return(mock_diff_file_patch)

          allow(LlmPrompter).to receive(:new).and_return(mock_llm_prompter)
          allow(mock_llm_prompter).to receive(:chat).and_return(mock_llm_response_with_comments)

          @llm_validator.checks = ["Ensure proper code comments"]
          @llm_validator.llm_model = "gpt-4o-mini"
        end

        it "Submits simple patch for review" do
          @llm_validator.system_prompt_template = "mock system template"
          @llm_validator.user_prompt_template = "mock user template\n{{CONTENT}}"
          allow(mock_llm_prompter).to receive(:chat).and_return(mock_llm_response_without_comments)

          @llm_validator.check

          expected_messages = [
            {
              role: "system",
              content: "mock system template"
            },
            {
              role: "user",
              content: "mock user template\n#{mock_patch_content_for_review}"
            }
          ]
          expect(mock_llm_prompter).to have_received(:chat).with(expected_messages)
          expect(@llm_validator.validation_errors.count).to eq(0)
          expect(@llm_validator).not_to have_received(:warn)
        end

        it "Replace all placeholders in the prompt templates" do
          all_placeholders = "{{CHECKS}}\n" \
            "{{JSON_FORMAT}}\n" \
            "{{FILE_PATH}}\n" \
            "{{CONTENT}}"
          @llm_validator.system_prompt_template = all_placeholders
          @llm_validator.user_prompt_template = all_placeholders

          allow(mock_llm_prompter).to receive(:chat).and_return(mock_llm_response_without_comments)

          @llm_validator.check

          expected_prompt = "  1. Ensure proper code comments\n" \
            "#{PromptBuilder::JSON_FORMAT}\n" \
            "#{mock_test_file_path}\n" \
            "#{mock_patch_content_for_review}"

          expected_messages = [
            {
              role: "system",
              content: expected_prompt
            },
            {
              role: "user",
              content: expected_prompt
            }
          ]
          expect(mock_llm_prompter).to have_received(:chat).with(expected_messages)
        end

        it "Parses LLM responses and sets the llm_responses attribute" do
          @llm_validator.system_prompt_template = nil
          @llm_validator.user_prompt_template = "mock user template"

          @llm_validator.check

          expect(@llm_validator.llm_responses.count).to eq(1)
          expect(@llm_validator.llm_responses.first.comments.count).to eq(1)
          comment = @llm_validator.llm_responses.first.comments.first
          expect(comment.line_number).to eq(1337)
          expect(comment.line_content).to eq("The line content")
          expect(comment.comment).to eq("The comment")
        end

        it "Parses LLM responses and posts warnings for all comments" do
          @llm_validator.check

          expect(@llm_validator).to have_received(:warn).with("The comment", file: mock_test_file_path, line: 1337)
        end

        it "Does not post warning for comments if :warn_for_llm_comments is false" do
          @llm_validator.warn_for_llm_comments = false

          @llm_validator.system_prompt_template = nil
          @llm_validator.user_prompt_template = "mock user template\n{{CONTENT}}"

          @llm_validator.check

          expect(@llm_validator).not_to have_received(:warn)
        end

        it "Posts a global warning if the llm_prompter fails" do
          allow(mock_llm_prompter).to receive(:chat).and_raise(StandardError, "Something went wrong")

          @llm_validator.check

          expect(@llm_validator).to have_received(:warn)
          expect(@llm_validator.validation_errors.count).to eq(1)
        end

        it "Posts a global warning if the llm_response was not valid JSON" do
          allow(mock_llm_prompter).to receive(:chat).and_return("{}\n")

          @llm_validator.check

          expect(@llm_validator).to have_received(:warn)
          expect(@llm_validator.validation_errors.count).to eq(1)
        end

        it "Does not post a global warning if the validation fails and :warn_for_validation_errors is false" do
          allow(mock_llm_prompter).to receive(:chat).and_raise(StandardError, "Something went wrong")
          @llm_validator.warn_for_validation_errors = false

          @llm_validator.check

          expected_error_message = "Failed to validate file: #{mock_test_file_path} with error: Something went wrong. LLM response: ''"
          expect(@llm_validator).not_to have_received(:warn)
          expect(@llm_validator.validation_errors).to eq([expected_error_message])
        end
      end

      describe "with renamed file git diff" do
        let(:mock_diff) { instance_double(Git::Diff) }
        let(:mock_test_file_old_path) { "spec/fixtures/OldFileName.kt" }
        let(:mock_test_file_new_path) { "spec/fixtures/TestFileWithIssues.kt" }

        let(:mock_diff_file) { instance_double(Git::Diff::DiffFile, path: mock_test_file_old_path, type: "modified", binary?: false) }
        let(:mock_llm_prompter) { instance_double(LlmPrompter) }
        let(:mock_diff_file_patch) { File.read("spec/fixtures/diff_file_renamed_file_patch.txt") }
        let(:mock_llm_response_without_comments) { File.read("spec/fixtures/llm_response_without_comments.json") }
        let(:mock_patch_content_for_review) { File.read("spec/fixtures/patch_for_review.txt") }

        before do
          allow(@llm_validator.git).to receive(:diff).and_return(mock_diff)
          allow(@llm_validator).to receive(:warn)
          allow(mock_diff).to receive(:select).and_return([mock_diff_file])
          allow(mock_diff_file).to receive(:patch).and_return(mock_diff_file_patch)

          allow(LlmPrompter).to receive(:new).and_return(mock_llm_prompter)
          allow(mock_llm_prompter).to receive(:chat).and_return(mock_llm_response_without_comments)

          @llm_validator.checks = ["Ensure proper code comments"]
          @llm_validator.llm_model = "gpt-4o-mini"
        end

        it "Submits renamed patch for review" do
          @llm_validator.system_prompt_template = "mock system template"
          @llm_validator.user_prompt_template = "mock user template\n{{CONTENT}}"
          allow(mock_llm_prompter).to receive(:chat).and_return(mock_llm_response_without_comments)

          @llm_validator.check

          expected_messages = [
            {
              role: "system",
              content: "mock system template"
            },
            {
              role: "user",
              content: "mock user template\n#{mock_patch_content_for_review}"
            }
          ]
          expect(mock_llm_prompter).to have_received(:chat).with(expected_messages)
          expect(@llm_validator.validation_errors.count).to eq(0)
          expect(@llm_validator).not_to have_received(:warn)
        end

        it "Replace all placeholders in the prompt templates" do
          all_placeholders = "{{CHECKS}}\n" \
            "{{JSON_FORMAT}}\n" \
            "{{FILE_PATH}}\n" \
            "{{CONTENT}}"
          @llm_validator.system_prompt_template = all_placeholders
          @llm_validator.user_prompt_template = all_placeholders

          allow(mock_llm_prompter).to receive(:chat).and_return(mock_llm_response_without_comments)

          @llm_validator.check

          expected_prompt = "  1. Ensure proper code comments\n" \
            "#{PromptBuilder::JSON_FORMAT}\n" \
            "#{mock_test_file_new_path}\n" \
            "#{mock_patch_content_for_review}"

          expected_messages = [
            {
              role: "system",
              content: expected_prompt
            },
            {
              role: "user",
              content: expected_prompt
            }
          ]
          expect(mock_llm_prompter).to have_received(:chat).with(expected_messages)
        end
      end
    end
  end
end
