class PracticeSession < ApplicationRecord
  belongs_to :student
  belongs_to :learning_goal, optional: true
  has_many :practice_problems, dependent: :destroy
  has_many :knowledge_nodes, as: :source

  validates :subject, presence: true
end

