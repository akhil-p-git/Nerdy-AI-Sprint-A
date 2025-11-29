class Student < ApplicationRecord
  has_many :learning_profiles, dependent: :destroy
  has_many :learning_goals, dependent: :destroy
  has_many :tutoring_sessions, dependent: :destroy
  has_many :conversations, dependent: :destroy
  has_many :practice_sessions, dependent: :destroy
  has_many :knowledge_nodes, dependent: :destroy

  validates :email, presence: true, uniqueness: true
  validates :external_id, presence: true, uniqueness: true
end

