# frozen_string_literal: true

module Danger
  class HunkContentBuilder

    attr_reader :file_filter, :git, :diff_context_extra_lines
    private :file_filter, :git, :diff_context_extra_lines

    def initialize(git:, file_filter:, diff_context_extra_lines:)
      @git = git
      @file_filter = file_filter
      @diff_context_extra_lines = diff_context_extra_lines
    end

    # Returns a list of #FileContent
    def build_file_contents
      diff_files_to_process = git.diff.select { |file| file_filter.allowed?(file.path) }
      diff_files_to_process.map do |diff_file|
        # Prepare a list of all file lines prefixed with its line number
        prefixed_file_content = prefix_file_lines_with_line_number(file_path: diff_file.path)

        # Get a list of all diff headers
        diff_headers = diff_file.patch.lines.select { |line| DiffHeader.valid_header?(line) }

        # Extract hunks from prefixed_file_content based on the diff_headers
        hunks_for_review = diff_headers.map do |diff_header|
          extract_file_lines_for_diff_header(file_lines: prefixed_file_content, diff_header_line: diff_header).join
        end
        FileContent.new(file_path: diff_file.path, hunks: hunks_for_review)
      end
    end

    private

    # Slices the provided file_lines according to the provided diff_header and diff_context_extra_lines.
    # Returns an #Array<String>
    def extract_file_lines_for_diff_header(file_lines:, diff_header_line:)
      diff_header = DiffHeader.parse(diff_header_line)
      hunk_start_index = [(diff_header.new_start - 1 - diff_context_extra_lines), 0].max
      hunk_end_index = [(diff_header.new_end - 1 + diff_context_extra_lines), (file_lines.count - 1)].min
      file_lines[hunk_start_index...hunk_end_index]
    end

    # Returns an #Array<String> of lines in the file prefixed with their respective line number
    def prefix_file_lines_with_line_number(file_path:)
      File.foreach(file_path).with_index(1).map do |line, line_number|
        "#{line_number}: #{line}"
      end
    end
  end
end
