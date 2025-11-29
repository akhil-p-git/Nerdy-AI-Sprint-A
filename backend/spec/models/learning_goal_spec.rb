require 'rails_helper'

RSpec.describe LearningGoal, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:subject) }
  end

  describe 'associations' do
    it { should belong_to(:student) }
  end

  describe 'status transitions' do
    let(:goal) { create(:learning_goal, status: :active, progress_percentage: 100) }

    it 'can be marked as completed' do
      goal.update!(status: :completed, completed_at: Time.current)
      expect(goal.status).to eq('completed')
    end
  end
end


