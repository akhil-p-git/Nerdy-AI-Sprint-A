class PracticeProblem < ApplicationRecord
  belongs_to :practice_session

  validates :question, presence: true
end

