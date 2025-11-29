class TutoringSession < ApplicationRecord
  belongs_to :student
  belongs_to :tutor, optional: true

  has_many :knowledge_nodes, as: :source
end

