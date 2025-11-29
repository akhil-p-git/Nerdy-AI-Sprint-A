class Conversation < ApplicationRecord
  belongs_to :student
  has_many :messages, dependent: :destroy
  has_many :knowledge_nodes, as: :source

  # status is a string in migration, could be enum but prompt says default 'active' string
end

