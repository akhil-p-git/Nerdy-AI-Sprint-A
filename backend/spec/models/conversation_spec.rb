require 'rails_helper'

RSpec.describe Conversation, type: :model do
  describe 'associations' do
    it { should belong_to(:student) }
    it { should have_many(:messages).dependent(:destroy) }
  end

  describe 'scopes' do
    let!(:active_conversation) { create(:conversation, status: 'active') }
    let!(:archived_conversation) { create(:conversation, status: 'archived') }

    it 'filters active conversations' do
      expect(Conversation.where(status: 'active')).to include(active_conversation)
      expect(Conversation.where(status: 'active')).not_to include(archived_conversation)
    end
  end
end


