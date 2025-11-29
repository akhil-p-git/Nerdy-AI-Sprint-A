require 'rails_helper'

RSpec.describe AI::ConversationService, type: :service do
  let(:student) { create(:student) }
  let(:service) { described_class.new(student: student) }

  describe '#initialize' do
    it 'creates a new conversation' do
      expect(service.conversation).to be_persisted
      expect(service.conversation.student).to eq(student)
    end

    it 'uses existing conversation when provided' do
      existing = create(:conversation, student: student)
      service_with_existing = described_class.new(student: student, conversation: existing)
      expect(service_with_existing.conversation).to eq(existing)
    end
  end

  describe '#send_message', vcr: { cassette_name: 'openai/chat_completion' } do
    it 'creates user and assistant messages' do
      expect {
        service.send_message('What is 2+2?', subject: 'math')
      }.to change { Message.count }.by(2)
    end

    it 'stores the conversation in memory' do
      allow_any_instance_of(AI::MemoryService).to receive(:store_interaction)

      service.send_message('Explain photosynthesis', subject: 'biology')

      expect(AI::MemoryService).to have_received(:store_interaction).once
    end
  end

  describe '#build_system_prompt' do
    it 'includes student name' do
      prompt = service.send(:build_system_prompt, 'math')
      expect(prompt).to include(student.first_name)
    end

    it 'includes subject' do
      prompt = service.send(:build_system_prompt, 'chemistry')
      expect(prompt).to include('chemistry')
    end
  end
end


