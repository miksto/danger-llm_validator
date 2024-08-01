# frozen_string_literal: true

# Holds a an array of chunks to send for review
class FileContent
  attr_reader :file_path, :hunks

  def initialize(file_path:, hunks:)
    @file_path = file_path
    @hunks = hunks
  end
end
