require 'rails_helper'

RSpec.describe Student, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:external_id) }
    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:external_id) }
  end

  describe 'associations' do
    it { should have_many(:conversations) }
    it { should have_many(:practice_sessions) }
    it { should have_many(:learning_goals) }
    it { should have_many(:learning_profiles) }
    it { should have_many(:tutoring_sessions) }
  end
end


