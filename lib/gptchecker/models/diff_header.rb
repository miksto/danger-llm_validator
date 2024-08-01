# frozen_string_literal: true

class DiffHeader
  attr_reader :original_start, :original_end, :original_count, :new_start, :new_end, :new_count

  DIFF_HEADER_REGEXP = /@@ -(\d+),?(\d+)? \+(\d+),?(\d+)? @@/.freeze

  def initialize(original_count:, new_start:, new_count:, original_start:)
    @original_start = original_start
    @original_count = original_count
    @new_start = new_start
    @new_count = new_count
    @original_end = original_start + original_count
    @new_end = new_start + new_count
  end

  # Returns true if the provided text matches the unified diff header format, otherwise false
  def self.valid_header?(text)
    text.match(DIFF_HEADER_REGEXP) != nil
  end

  # Returns an instance of #DiffHeader or nil if the provided header did not match the unified diff format
  def self.parse(header)
    # Regular expression to match the unified diff header
    match = header.match(DIFF_HEADER_REGEXP)

    if match
      original_start = match[1].to_i
      original_count = match[2].to_i
      new_start = match[3].to_i
      new_count = match[4].to_i

      new(
        original_start: original_start,
        original_count: original_count,
        new_start: new_start,
        new_count: new_count
      )
    end
  end
end
