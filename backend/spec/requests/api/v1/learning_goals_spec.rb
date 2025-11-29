require 'rails_helper'

RSpec.describe 'Api::V1::LearningGoals', type: :request do
  let(:student) { create(:student) }
  let(:headers) { auth_headers(student) }

  describe 'GET /api/v1/learning_goals' do
    before do
      create_list(:learning_goal, 3, student: student)
      create(:learning_goal) # Different student
    end

    it 'returns student goals' do
      get '/api/v1/learning_goals', headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response.length).to eq(3)
    end

    it 'filters by status' do
      create(:learning_goal, :completed, student: student)

      get '/api/v1/learning_goals', params: { status: 'completed' }, headers: headers

      expect(json_response.length).to eq(1)
      expect(json_response.first[:status]).to eq('completed')
    end
  end

  describe 'POST /api/v1/learning_goals' do
    let(:params) do
      {
        subject: 'physics',
        title: 'Master mechanics',
        description: 'Learn Newton\'s laws'
      }
    end

    it 'creates a goal' do
      expect {
        post '/api/v1/learning_goals', params: params, headers: headers
      }.to change { LearningGoal.count }.by(1)

      expect(response).to have_http_status(:created)
      expect(json_response[:title]).to eq('Master mechanics')
      expect(json_response[:status]).to eq('active')
    end
  end

  describe 'PUT /api/v1/learning_goals/:id' do
    let(:goal) { create(:learning_goal, student: student) }

    it 'updates the goal' do
      put "/api/v1/learning_goals/#{goal.id}",
        params: { progress_percentage: 50 },
        headers: headers

      expect(response).to have_http_status(:ok)
      expect(goal.reload.progress_percentage).to eq(50)
    end
  end
end


