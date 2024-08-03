# frozen_string_literal: true

require File.expand_path("spec_helper", __dir__)

module Danger
  describe Danger::FileFilter do
    let(:mock_test_file_path) { "spec/fixtures/TestFileWithIssues.kt" }

    it "Allows the test file if all filters are empty" do
      file_filter = FileFilter.new(
        include_patterns: [],
        exclude_patterns: []
      )

      result = file_filter.allowed?(mock_test_file_path)

      expect(result).to eq(true)
    end

    it "Allows the test file if the inclusion filter matches it" do
      file_filter = FileFilter.new(
        include_patterns: ["**/*.kt"],
        exclude_patterns: []
      )

      result = file_filter.allowed?(mock_test_file_path)

      expect(result).to eq(true)
    end

    it "Does not allow the test file if the inclusion filter does not match it" do
      file_filter = FileFilter.new(
        include_patterns: ["**/*.rb"],
        exclude_patterns: []
      )

      result = file_filter.allowed?(mock_test_file_path)

      expect(result).to eq(false)
    end

    it "Does not allow the test file if both the inclusion and exclusion filter matches it" do
      file_filter = FileFilter.new(
        include_patterns: ["**/*.kt"],
        exclude_patterns: [mock_test_file_path]
      )

      result = file_filter.allowed?(mock_test_file_path)

      expect(result).to eq(false)
    end

    it "Does not allow the test file if only exclusion filter matches it" do
      file_filter = FileFilter.new(
        include_patterns: [],
        exclude_patterns: [mock_test_file_path]
      )

      result = file_filter.allowed?(mock_test_file_path)

      expect(result).to eq(false)
    end
  end
end
