# Represents a book that students can request.
class Book < ActiveRecord::Base
  scope :featured, where(featured: true).order(:rank)

  # The default book for new requests.
  def self.default_book
    find_or_create_by_title "Atlas Shrugged"
  end

  def to_s
    title
  end
end
