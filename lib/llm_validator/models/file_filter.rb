# frozen_string_literal: true

class FileFilter
  attr_accessor :include_patterns, :exclude_patterns

  def initialize(include_patterns:, exclude_patterns:)
    @include_patterns = include_patterns
    @exclude_patterns = exclude_patterns
  end

  def allowed?(file_path)
    included = include_patterns.empty? || include_patterns.any? { |pattern| File.fnmatch(pattern, file_path) }
    excluded = exclude_patterns.any? { |pattern| File.fnmatch(pattern, file_path) }
    included && !excluded
  end
end
