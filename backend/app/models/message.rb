class Message < ApplicationRecord
  belongs_to :conversation

  validates :role, presence: true
  validates :content, presence: true
end

