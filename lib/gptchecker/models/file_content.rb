# frozen_string_literal: true

class FileContent
  attr_reader :file_path, :content

  def initialize(file_path:, content:)
    @file_path = file_path
    @content = content
  end
end
