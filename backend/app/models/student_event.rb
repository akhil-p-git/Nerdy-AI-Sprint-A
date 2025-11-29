class StudentEvent < ApplicationRecord
  belongs_to :student
  scope :unacknowledged, -> { where(acknowledged: false) }
  scope :active, -> { where('expires_at IS NULL OR expires_at > ?', Time.current) }
end


