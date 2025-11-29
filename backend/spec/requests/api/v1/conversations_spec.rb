require 'rails_helper'

RSpec.describe 'Api::V1::Conversations', type: :request do
  let(:student) { create(:student) }
  let(:headers) { auth_headers(student) }

  describe 'GET /api/v1/conversations' do
    before do
      create_list(:conversation, 3, student: student)
      create(:conversation) # Different student
    end

    it 'returns student conversations' do
      get '/api/v1/conversations', headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response.length).to eq(3)
    end

    it 'returns 401 without auth' do
      get '/api/v1/conversations'

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /api/v1/conversations' do
    it 'creates a new conversation' do
      expect {
        post '/api/v1/conversations',
          params: { subject: 'math' },
          headers: headers
      }.to change { Conversation.count }.by(1)

      expect(response).to have_http_status(:created)
      expect(json_response[:subject]).to eq('math')
    end
  end

  describe 'GET /api/v1/conversations/:id' do
    let(:conversation) { create(:conversation, :with_messages, student: student) }

    it 'returns conversation with messages' do
      get "/api/v1/conversations/#{conversation.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response[:messages]).to be_present
    end

    it 'returns 404 for other student conversation' do
      other_conversation = create(:conversation)

      get "/api/v1/conversations/#{other_conversation.id}", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end
end


