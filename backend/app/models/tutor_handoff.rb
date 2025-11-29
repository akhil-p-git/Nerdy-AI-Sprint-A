class TutorHandoff < ApplicationRecord
  belongs_to :student
  belongs_to :conversation, optional: true
  enum :status, { pending: 'pending', confirmed: 'confirmed', completed: 'completed', cancelled: 'cancelled' }
end


