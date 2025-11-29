require 'rails_helper'

RSpec.describe 'Api::V1::PracticeSessions', type: :request do
  let(:student) { create(:student) }
  let(:headers) { auth_headers(student) }

  describe 'POST /api/v1/practice_sessions', vcr: { cassette_name: 'openai/practice_generation' } do
    let(:params) do
      {
        subject: 'mathematics',
        session_type: 'quiz',
        num_problems: 5
      }
    end

    it 'creates a practice session with problems' do
      post '/api/v1/practice_sessions', params: params, headers: headers

      expect(response).to have_http_status(:created)
      expect(json_response[:problems].length).to eq(5)
    end
  end

  describe 'POST /api/v1/practice_sessions/:id/submit' do
    let(:session) { create(:practice_session, :with_problems, student: student) }
    let(:problem) { session.practice_problems.first }

    before { problem.update!(correct_answer: 'A') }

    it 'returns correct result for right answer' do
      post "/api/v1/practice_sessions/#{session.id}/submit",
        params: { problem_id: problem.id, answer: 'A' },
        headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response[:is_correct]).to be true
    end

    it 'returns feedback for wrong answer' do
      post "/api/v1/practice_sessions/#{session.id}/submit",
        params: { problem_id: problem.id, answer: 'B' },
        headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response[:is_correct]).to be false
      expect(json_response[:correct_answer]).to eq('A')
    end
  end

  describe 'POST /api/v1/practice_sessions/:id/complete' do
    let(:session) { create(:practice_session, student: student, correct_answers: 7, total_problems: 10) }

    it 'completes session and returns results' do
      post "/api/v1/practice_sessions/#{session.id}/complete", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response[:accuracy]).to eq(70)
      expect(session.reload.completed_at).to be_present
    end
  end
end


