class AnalyticsEvent < ApplicationRecord
  belongs_to :student, optional: true
  validates :event_name, presence: true
  validates :occurred_at, presence: true
end


