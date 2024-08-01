# frozen_string_literal: true

require_relative "../models/file_content"
require_relative "../models/diff_header"

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
    git.diff.select { |file| file_filter.allowed?(file.path) }.map do |diff_file|
      diff_headers = diff_file.patch.lines.select do |line|
        line.match(/^@@ -\d+,\d+ \+\d+,\d+ @@/)
      end

      prefixed_file_content = file_lines_prefixed_with_line_number(file_path: diff_file.path)

      hunks_for_review = diff_headers.map do |diff_header|
        extract_file_lines_for_diff_header(file_lines: prefixed_file_content, diff_header_line: diff_header).join
      end
      FileContent.new(file_path: diff_file.path, content: hunks_for_review)
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
  def file_lines_prefixed_with_line_number(file_path:)
    File.foreach(file_path).with_index(1).map do |line, line_number|
      "#{line_number}: #{line}"
    end
  end
end
