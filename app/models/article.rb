class Article < ApplicationRecord
  belongs_to :author
  has_many :comments

  validates :title, presence: true, length: { maximum: 120 }
  validates :body, presence: true, length: { minimum: 20 }
  validates :score, numericality: { only_integer: true, in: 0..100 }

  scope :published, -> { where(published: true) }
end
