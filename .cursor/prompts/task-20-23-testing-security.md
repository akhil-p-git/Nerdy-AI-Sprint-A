# One-Shot Prompt: Testing & Security (Tasks 20, 23)

## Context
Implementing comprehensive testing and security hardening for the Nerdy AI Study Companion before production deployment.

## Your Mission
- **Task 20:** Unit and Integration Tests (>80% coverage)
- **Task 23:** Security Audit and Hardening

---

## Task 20: Unit and Integration Tests

### Backend Testing Setup

Add to `backend/Gemfile`:
```ruby
group :test do
  gem 'rspec-rails'
  gem 'factory_bot_rails'
  gem 'faker'
  gem 'shoulda-matchers'
  gem 'webmock'
  gem 'vcr'
  gem 'simplecov', require: false
  gem 'database_cleaner-active_record'
end
```

Run setup:
```bash
rails generate rspec:install
```

### SimpleCov Configuration
Create `backend/spec/spec_helper.rb`:
```ruby
require 'simplecov'
SimpleCov.start 'rails' do
  add_filter '/spec/'
  add_filter '/config/'
  add_filter '/vendor/'

  add_group 'Controllers', 'app/controllers'
  add_group 'Models', 'app/models'
  add_group 'Services', 'app/services'
  add_group 'Jobs', 'app/jobs'
  add_group 'Serializers', 'app/serializers'

  minimum_coverage 80
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
end
```

### Rails Helper
Create `backend/spec/rails_helper.rb`:
```ruby
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'

abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'rspec/rails'

Dir[Rails.root.join('spec', 'support', '**', '*.rb')].sort.each { |f| require f }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  config.fixture_path = Rails.root.join('spec/fixtures')
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.include FactoryBot::Syntax::Methods
  config.include RequestSpecHelper, type: :request

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end
end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
```

### Support Files
Create `backend/spec/support/request_spec_helper.rb`:
```ruby
module RequestSpecHelper
  def json_response
    JSON.parse(response.body, symbolize_names: true)
  end

  def auth_headers(student)
    token = JwtService.encode(student_id: student.id)
    { 'Authorization' => "Bearer #{token}" }
  end

  def parent_auth_headers(parent)
    token = JwtService.encode(parent_id: parent.id)
    { 'Authorization' => "Bearer #{token}" }
  end

  def admin_headers
    { 'X-Admin-Token' => ENV['ADMIN_TOKEN'] || 'test-admin-token' }
  end
end
```

Create `backend/spec/support/vcr_setup.rb`:
```ruby
require 'vcr'

VCR.configure do |config|
  config.cassette_library_dir = 'spec/cassettes'
  config.hook_into :webmock
  config.configure_rspec_metadata!

  config.filter_sensitive_data('<OPENAI_API_KEY>') { ENV['OPENAI_API_KEY'] }
  config.filter_sensitive_data('<NERDY_API_KEY>') { ENV['NERDY_API_KEY'] }

  config.default_cassette_options = {
    record: :new_episodes,
    match_requests_on: [:method, :uri, :body]
  }
end
```

### Factories
Create `backend/spec/factories/students.rb`:
```ruby
FactoryBot.define do
  factory :student do
    external_id { "nerdy_#{Faker::Alphanumeric.alphanumeric(number: 10)}" }
    email { Faker::Internet.email }
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    preferences { {} }
    learning_style { {} }
  end
end
```

Create `backend/spec/factories/conversations.rb`:
```ruby
FactoryBot.define do
  factory :conversation do
    student
    subject { %w[mathematics physics chemistry english].sample }
    status { 'active' }

    trait :with_messages do
      after(:create) do |conversation|
        create_list(:message, 3, conversation: conversation, role: 'user')
        create_list(:message, 3, conversation: conversation, role: 'assistant')
      end
    end
  end

  factory :message do
    conversation
    role { 'user' }
    content { Faker::Lorem.paragraph }
    metadata { {} }
  end
end
```

Create `backend/spec/factories/practice_sessions.rb`:
```ruby
FactoryBot.define do
  factory :practice_session do
    student
    subject { 'mathematics' }
    session_type { 'quiz' }
    total_problems { 10 }
    correct_answers { rand(5..10) }
    time_spent_seconds { rand(300..900) }
    struggled_topics { [] }

    trait :completed do
      completed_at { Time.current }
    end

    trait :with_problems do
      after(:create) do |session|
        create_list(:practice_problem, session.total_problems, practice_session: session)
      end
    end
  end

  factory :practice_problem do
    practice_session
    problem_type { 'multiple_choice' }
    question { Faker::Lorem.question }
    correct_answer { 'A' }
    options { ['A', 'B', 'C', 'D'] }
    difficulty_level { rand(1..10) }
    topic { 'algebra' }
  end
end
```

Create `backend/spec/factories/learning_goals.rb`:
```ruby
FactoryBot.define do
  factory :learning_goal do
    student
    subject { 'mathematics' }
    title { "Master #{Faker::Educator.subject}" }
    description { Faker::Lorem.sentence }
    status { :active }
    progress_percentage { rand(0..100) }
    target_date { 30.days.from_now }
    milestones { [] }

    trait :completed do
      status { :completed }
      progress_percentage { 100 }
      completed_at { Time.current }
    end
  end
end
```

Create `backend/spec/factories/learning_profiles.rb`:
```ruby
FactoryBot.define do
  factory :learning_profile do
    student
    subject { 'mathematics' }
    proficiency_level { rand(1..10) }
    strengths { ['algebra', 'geometry'] }
    weaknesses { ['calculus'] }
    knowledge_gaps { [] }
  end
end
```

### Model Tests
Create `backend/spec/models/student_spec.rb`:
```ruby
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
```

Create `backend/spec/models/conversation_spec.rb`:
```ruby
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
```

Create `backend/spec/models/learning_goal_spec.rb`:
```ruby
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
```

### Service Tests
Create `backend/spec/services/ai/conversation_service_spec.rb`:
```ruby
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
```

Create `backend/spec/services/ai/practice_service_spec.rb`:
```ruby
require 'rails_helper'

RSpec.describe AI::PracticeService, type: :service do
  let(:student) { create(:student) }
  let(:service) { described_class.new(student: student) }

  describe '#generate_session', vcr: { cassette_name: 'openai/practice_generation' } do
    it 'creates a practice session with problems' do
      session = service.generate_session(
        subject: 'mathematics',
        session_type: 'quiz',
        num_problems: 5
      )

      expect(session).to be_persisted
      expect(session.practice_problems.count).to eq(5)
    end

    it 'sets correct attributes on session' do
      session = service.generate_session(
        subject: 'physics',
        session_type: 'flashcards',
        num_problems: 3
      )

      expect(session.subject).to eq('physics')
      expect(session.session_type).to eq('flashcards')
      expect(session.total_problems).to eq(3)
    end
  end

  describe '#submit_answer' do
    let(:session) { create(:practice_session, :with_problems, student: student) }
    let(:problem) { session.practice_problems.first }

    it 'records correct answer' do
      problem.update!(correct_answer: 'A')

      result = service.submit_answer(problem.id, 'A')

      expect(result[:is_correct]).to be true
      expect(problem.reload.is_correct).to be true
    end

    it 'records incorrect answer' do
      problem.update!(correct_answer: 'A')

      result = service.submit_answer(problem.id, 'B')

      expect(result[:is_correct]).to be false
      expect(problem.reload.is_correct).to be false
    end

    it 'updates session statistics' do
      problem.update!(correct_answer: 'A')

      expect {
        service.submit_answer(problem.id, 'A')
      }.to change { session.reload.correct_answers }.by(1)
    end
  end

  describe '#complete_session' do
    let(:session) { create(:practice_session, student: student, correct_answers: 8, total_problems: 10) }

    it 'marks session as completed' do
      result = service.complete_session(session.id)

      expect(session.reload.completed_at).not_to be_nil
      expect(result[:accuracy]).to eq(80)
    end

    it 'updates learning profile' do
      profile = create(:learning_profile, student: student, subject: session.subject, proficiency_level: 5)

      service.complete_session(session.id)

      # High accuracy should increase proficiency
      expect(profile.reload.proficiency_level).to be >= 5
    end
  end
end
```

Create `backend/spec/services/retention/engagement_tracker_spec.rb`:
```ruby
require 'rails_helper'

RSpec.describe Retention::EngagementTracker, type: :service do
  let(:student) { create(:student, created_at: 10.days.ago) }
  let(:tracker) { described_class.new(student: student) }

  describe '#engagement_score' do
    context 'with active student' do
      before do
        create_list(:practice_session, 5, student: student, created_at: 3.days.ago)
        create_list(:conversation, 3, student: student, updated_at: 2.days.ago)
      end

      it 'returns positive score' do
        expect(tracker.engagement_score).to be > 0
      end
    end

    context 'with inactive student' do
      it 'returns low score' do
        expect(tracker.engagement_score).to be < 50
      end
    end
  end

  describe '#needs_nudge?' do
    context 'new student with few sessions' do
      let(:student) { create(:student, created_at: 8.days.ago) }

      it 'returns true when less than 3 sessions' do
        create(:tutoring_session, student: student)

        expect(tracker.needs_nudge?).to be true
      end
    end

    context 'inactive student' do
      let(:student) { create(:student, created_at: 30.days.ago) }

      it 'returns true when no recent activity' do
        expect(tracker.needs_nudge?).to be true
      end
    end
  end

  describe '#recommended_nudge' do
    context 'new student low sessions' do
      let(:student) { create(:student, created_at: 8.days.ago) }

      before { create(:tutoring_session, student: student) }

      it 'recommends session booking' do
        expect(tracker.recommended_nudge).to eq(:new_student_sessions)
      end
    end
  end
end
```

### Controller/Request Tests
Create `backend/spec/requests/api/v1/conversations_spec.rb`:
```ruby
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
```

Create `backend/spec/requests/api/v1/practice_sessions_spec.rb`:
```ruby
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
```

Create `backend/spec/requests/api/v1/learning_goals_spec.rb`:
```ruby
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
```

### Frontend Testing Setup

Add dependencies to `frontend/package.json`:
```json
{
  "devDependencies": {
    "@testing-library/react": "^14.0.0",
    "@testing-library/jest-dom": "^6.0.0",
    "@testing-library/user-event": "^14.0.0",
    "vitest": "^1.0.0",
    "@vitest/coverage-v8": "^1.0.0",
    "jsdom": "^22.0.0",
    "msw": "^2.0.0"
  }
}
```

Create `frontend/vitest.config.ts`:
```typescript
import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: ['./src/test/setup.ts'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'html'],
      exclude: ['node_modules/', 'src/test/'],
      thresholds: {
        lines: 80,
        functions: 80,
        branches: 80,
        statements: 80
      }
    }
  }
});
```

Create `frontend/src/test/setup.ts`:
```typescript
import '@testing-library/jest-dom';
import { afterAll, afterEach, beforeAll } from 'vitest';
import { server } from './mocks/server';

beforeAll(() => server.listen({ onUnhandledRequest: 'error' }));
afterEach(() => server.resetHandlers());
afterAll(() => server.close());
```

Create `frontend/src/test/mocks/handlers.ts`:
```typescript
import { http, HttpResponse } from 'msw';

export const handlers = [
  http.get('/api/v1/conversations', () => {
    return HttpResponse.json([
      { id: 1, subject: 'math', status: 'active', messages: [] },
      { id: 2, subject: 'physics', status: 'active', messages: [] }
    ]);
  }),

  http.post('/api/v1/conversations', () => {
    return HttpResponse.json({
      id: 3,
      subject: 'chemistry',
      status: 'active',
      messages: []
    });
  }),

  http.get('/api/v1/learning_goals', () => {
    return HttpResponse.json([
      { id: 1, title: 'Master algebra', subject: 'math', progress_percentage: 50, status: 'active' }
    ]);
  }),

  http.get('/api/v1/stats', () => {
    return HttpResponse.json({
      total_sessions: 10,
      total_practice_problems: 100,
      average_accuracy: 75,
      current_streak: 5,
      goals_completed: 2,
      active_goals: 3
    });
  }),

  http.post('/api/v1/practice_sessions', () => {
    return HttpResponse.json({
      id: 1,
      subject: 'math',
      session_type: 'quiz',
      total_problems: 5,
      correct_answers: 0,
      problems: [
        { id: 1, question: 'What is 2+2?', options: ['3', '4', '5', '6'], type: 'multiple_choice' }
      ]
    });
  })
];
```

Create `frontend/src/test/mocks/server.ts`:
```typescript
import { setupServer } from 'msw/node';
import { handlers } from './handlers';

export const server = setupServer(...handlers);
```

### Component Tests
Create `frontend/src/components/chat/__tests__/ChatInput.test.tsx`:
```typescript
import { render, screen, fireEvent } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, it, expect, vi } from 'vitest';
import { ChatInput } from '../ChatInput';
import { ChatProvider } from '../../../contexts/ChatContext';

const mockSendMessage = vi.fn();

vi.mock('../../../contexts/ChatContext', async () => {
  const actual = await vi.importActual('../../../contexts/ChatContext');
  return {
    ...actual,
    useChat: () => ({
      sendMessage: mockSendMessage,
      isStreaming: false
    })
  };
});

describe('ChatInput', () => {
  beforeEach(() => {
    mockSendMessage.mockClear();
  });

  it('renders input field', () => {
    render(<ChatInput />);
    expect(screen.getByPlaceholderText(/ask me anything/i)).toBeInTheDocument();
  });

  it('sends message on submit', async () => {
    const user = userEvent.setup();
    render(<ChatInput />);

    const input = screen.getByPlaceholderText(/ask me anything/i);
    await user.type(input, 'Hello AI');
    await user.click(screen.getByRole('button'));

    expect(mockSendMessage).toHaveBeenCalledWith('Hello AI');
  });

  it('sends message on Enter key', async () => {
    const user = userEvent.setup();
    render(<ChatInput />);

    const input = screen.getByPlaceholderText(/ask me anything/i);
    await user.type(input, 'Hello AI{Enter}');

    expect(mockSendMessage).toHaveBeenCalledWith('Hello AI');
  });

  it('does not send empty message', async () => {
    const user = userEvent.setup();
    render(<ChatInput />);

    await user.click(screen.getByRole('button'));

    expect(mockSendMessage).not.toHaveBeenCalled();
  });

  it('clears input after sending', async () => {
    const user = userEvent.setup();
    render(<ChatInput />);

    const input = screen.getByPlaceholderText(/ask me anything/i);
    await user.type(input, 'Hello AI{Enter}');

    expect(input).toHaveValue('');
  });
});
```

Create `frontend/src/components/practice/__tests__/QuizCard.test.tsx`:
```typescript
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, it, expect, vi } from 'vitest';
import { QuizCard } from '../QuizCard';

const mockPractice = {
  lastResult: null,
  isLoading: false,
  submitAnswer: vi.fn(),
  showExplanation: false
};

const mockProblem = {
  id: 1,
  type: 'multiple_choice',
  question: 'What is 2+2?',
  options: ['3', '4', '5', '6'],
  difficulty: 5,
  topic: 'arithmetic',
  answered: false,
  is_correct: null
};

describe('QuizCard', () => {
  it('renders question and options', () => {
    render(<QuizCard problem={mockProblem} practice={mockPractice as any} />);

    expect(screen.getByText('What is 2+2?')).toBeInTheDocument();
    expect(screen.getByText('A.')).toBeInTheDocument();
    expect(screen.getByText('3')).toBeInTheDocument();
    expect(screen.getByText('4')).toBeInTheDocument();
  });

  it('allows selecting an answer', async () => {
    const user = userEvent.setup();
    render(<QuizCard problem={mockProblem} practice={mockPractice as any} />);

    await user.click(screen.getByText('4'));

    // Check option is selected (has indigo border)
    const option = screen.getByText('4').closest('button');
    expect(option).toHaveClass('border-indigo-500');
  });

  it('submits answer on button click', async () => {
    const user = userEvent.setup();
    render(<QuizCard problem={mockProblem} practice={mockPractice as any} />);

    await user.click(screen.getByText('4'));
    await user.click(screen.getByText('Submit Answer'));

    expect(mockPractice.submitAnswer).toHaveBeenCalledWith('4');
  });

  it('shows result after submission', () => {
    const practiceWithResult = {
      ...mockPractice,
      lastResult: {
        is_correct: true,
        correct_answer: '4',
        explanation: '2+2 equals 4',
        feedback: 'Great job!'
      },
      showExplanation: true
    };

    render(<QuizCard problem={mockProblem} practice={practiceWithResult as any} />);

    expect(screen.getByText('Correct!')).toBeInTheDocument();
  });
});
```

Create `frontend/src/hooks/__tests__/usePractice.test.ts`:
```typescript
import { renderHook, act, waitFor } from '@testing-library/react';
import { describe, it, expect } from 'vitest';
import { usePractice } from '../usePractice';

describe('usePractice', () => {
  it('initializes with null session', () => {
    const { result } = renderHook(() => usePractice());

    expect(result.current.session).toBeNull();
    expect(result.current.currentProblem).toBeNull();
    expect(result.current.isLoading).toBe(false);
  });

  it('starts a practice session', async () => {
    const { result } = renderHook(() => usePractice());

    await act(async () => {
      await result.current.startSession('math', 'quiz', 5);
    });

    await waitFor(() => {
      expect(result.current.session).not.toBeNull();
      expect(result.current.session?.subject).toBe('math');
    });
  });

  it('tracks current problem index', async () => {
    const { result } = renderHook(() => usePractice());

    await act(async () => {
      await result.current.startSession('math', 'quiz', 5);
    });

    expect(result.current.currentIndex).toBe(0);

    // Simulate answering
    await act(async () => {
      // Mock answer submission would set lastResult
    });
  });

  it('calculates progress correctly', async () => {
    const { result } = renderHook(() => usePractice());

    await act(async () => {
      await result.current.startSession('math', 'quiz', 5);
    });

    // First problem of 5 = 20% progress
    expect(result.current.progress).toBe(20);
  });
});
```

---

## Task 23: Security Audit and Hardening

### Input Validation
Create `backend/app/validators/input_sanitizer.rb`:
```ruby
class InputSanitizer
  class << self
    def sanitize_string(input)
      return nil if input.nil?

      input.to_s
        .strip
        .gsub(/[\x00-\x08\x0B\x0C\x0E-\x1F]/, '') # Remove control characters
    end

    def sanitize_html(input)
      return nil if input.nil?

      ActionController::Base.helpers.sanitize(
        input.to_s,
        tags: %w[p br strong em ul ol li a code pre],
        attributes: %w[href class]
      )
    end

    def sanitize_email(input)
      return nil if input.nil?

      email = input.to_s.strip.downcase
      return nil unless email.match?(URI::MailTo::EMAIL_REGEXP)

      email
    end

    def sanitize_integer(input, min: nil, max: nil)
      value = input.to_i
      value = [value, min].max if min
      value = [value, max].min if max
      value
    end

    def sanitize_array(input, allowed_values: nil)
      return [] unless input.is_a?(Array)

      result = input.map { |i| sanitize_string(i) }.compact
      result = result.select { |i| allowed_values.include?(i) } if allowed_values
      result
    end
  end
end
```

### Parameter Validation Concern
Create `backend/app/controllers/concerns/parameter_validation.rb`:
```ruby
module ParameterValidation
  extend ActiveSupport::Concern

  included do
    before_action :validate_content_type
  end

  private

  def validate_content_type
    return unless request.post? || request.put? || request.patch?
    return if request.content_type&.include?('application/json')
    return if request.content_type&.include?('multipart/form-data')

    render json: { error: 'Invalid content type' }, status: :unsupported_media_type
  end

  def validate_required_params(*keys)
    missing = keys.select { |k| params[k].blank? }
    return if missing.empty?

    render json: { error: "Missing required parameters: #{missing.join(', ')}" }, status: :bad_request
  end

  def sanitize_params(param_key, schema)
    return {} unless params[param_key]

    schema.each_with_object({}) do |(key, type), result|
      value = params[param_key][key]
      next if value.nil?

      result[key] = case type
      when :string then InputSanitizer.sanitize_string(value)
      when :integer then InputSanitizer.sanitize_integer(value)
      when :email then InputSanitizer.sanitize_email(value)
      when :html then InputSanitizer.sanitize_html(value)
      when Array then InputSanitizer.sanitize_array(value, allowed_values: type)
      else value
      end
    end
  end
end
```

### CSRF Protection
Update `backend/app/controllers/application_controller.rb`:
```ruby
class ApplicationController < ActionController::API
  include Authenticatable
  include ParameterValidation

  # For API-only apps, we use JWT instead of CSRF tokens
  # But we still protect against CSRF for browser-based requests

  before_action :verify_request_origin

  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity
  rescue_from ActionController::ParameterMissing, with: :bad_request

  private

  def verify_request_origin
    return unless request.headers['Origin'].present?

    allowed_origins = [
      ENV['FRONTEND_URL'],
      'http://localhost:5173',
      'http://localhost:3001'
    ].compact

    unless allowed_origins.include?(request.headers['Origin'])
      render json: { error: 'Invalid origin' }, status: :forbidden
    end
  end

  def not_found(exception)
    render json: { error: 'Resource not found' }, status: :not_found
  end

  def unprocessable_entity(exception)
    render json: { error: exception.record.errors.full_messages }, status: :unprocessable_entity
  end

  def bad_request(exception)
    render json: { error: exception.message }, status: :bad_request
  end
end
```

### SQL Injection Prevention
Create `backend/app/services/security/query_sanitizer.rb`:
```ruby
module Security
  class QuerySanitizer
    DANGEROUS_PATTERNS = [
      /;\s*drop\s+/i,
      /;\s*delete\s+/i,
      /;\s*update\s+/i,
      /;\s*insert\s+/i,
      /union\s+select/i,
      /--/,
      /\/\*/
    ].freeze

    class << self
      def safe?(input)
        return true if input.nil?

        str = input.to_s
        DANGEROUS_PATTERNS.none? { |pattern| str.match?(pattern) }
      end

      def sanitize_for_like(input)
        return '' if input.nil?

        input.to_s.gsub(/[%_\\]/) { |c| "\\#{c}" }
      end

      def validate_sort_column(column, allowed_columns)
        return allowed_columns.first unless allowed_columns.include?(column.to_s)

        column.to_s
      end

      def validate_sort_direction(direction)
        %w[asc desc].include?(direction.to_s.downcase) ? direction.to_s.downcase : 'asc'
      end
    end
  end
end
```

### XSS Protection
Create `backend/app/services/security/xss_sanitizer.rb`:
```ruby
module Security
  class XssSanitizer
    SCRIPT_PATTERNS = [
      /<script\b[^>]*>.*?<\/script>/mi,
      /javascript:/i,
      /on\w+\s*=/i,
      /data:/i
    ].freeze

    class << self
      def sanitize(input)
        return nil if input.nil?
        return input unless input.is_a?(String)

        result = input.dup

        # Remove script tags and event handlers
        SCRIPT_PATTERNS.each do |pattern|
          result.gsub!(pattern, '')
        end

        # Encode HTML entities
        CGI.escapeHTML(result)
      end

      def sanitize_hash(hash)
        hash.transform_values do |value|
          case value
          when String then sanitize(value)
          when Hash then sanitize_hash(value)
          when Array then value.map { |v| v.is_a?(String) ? sanitize(v) : v }
          else value
          end
        end
      end
    end
  end
end
```

### Secure Headers Middleware
Create `backend/app/middleware/secure_headers.rb`:
```ruby
class SecureHeaders
  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, response = @app.call(env)

    # Security headers
    headers['X-Content-Type-Options'] = 'nosniff'
    headers['X-Frame-Options'] = 'DENY'
    headers['X-XSS-Protection'] = '1; mode=block'
    headers['Referrer-Policy'] = 'strict-origin-when-cross-origin'
    headers['Permissions-Policy'] = 'geolocation=(), microphone=(), camera=()'

    # Content Security Policy
    headers['Content-Security-Policy'] = csp_header

    # Strict Transport Security (for production)
    if Rails.env.production?
      headers['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains'
    end

    [status, headers, response]
  end

  private

  def csp_header
    [
      "default-src 'self'",
      "script-src 'self' 'unsafe-inline' 'unsafe-eval'",
      "style-src 'self' 'unsafe-inline'",
      "img-src 'self' data: https:",
      "font-src 'self' data:",
      "connect-src 'self' #{allowed_api_origins}",
      "frame-ancestors 'none'"
    ].join('; ')
  end

  def allowed_api_origins
    [
      ENV['FRONTEND_URL'],
      'wss://*.nerdy.com',
      'https://api.openai.com'
    ].compact.join(' ')
  end
end
```

Add to `backend/config/application.rb`:
```ruby
config.middleware.use SecureHeaders
```

### COPPA Compliance
Create `backend/app/services/compliance/coppa_service.rb`:
```ruby
module Compliance
  class CoppaService
    MIN_AGE_WITHOUT_CONSENT = 13

    class << self
      def requires_parental_consent?(birth_date)
        return true if birth_date.nil?

        age = calculate_age(birth_date)
        age < MIN_AGE_WITHOUT_CONSENT
      end

      def can_collect_data?(student)
        return true unless requires_parental_consent?(student.birth_date)

        # Check for parental consent
        ParentalConsent.exists?(
          student: student,
          status: 'approved',
          expires_at: Time.current..
        )
      end

      def sensitive_data_fields
        %w[
          email
          phone_number
          address
          birth_date
          school_name
          parent_email
        ]
      end

      def anonymize_student_data(student)
        # Replace PII with anonymized values
        student.update!(
          email: "anonymized_#{student.id}@example.com",
          first_name: 'Anonymized',
          last_name: 'User',
          preferences: {},
          learning_style: {}
        )

        # Remove from related data
        student.conversations.destroy_all
        student.knowledge_nodes.destroy_all

        Rails.logger.info("Student #{student.id} data anonymized for COPPA compliance")
      end

      private

      def calculate_age(birth_date)
        today = Date.current
        age = today.year - birth_date.year
        age -= 1 if today < birth_date + age.years
        age
      end
    end
  end
end
```

### Data Encryption
Create `backend/app/services/security/encryption_service.rb`:
```ruby
module Security
  class EncryptionService
    class << self
      def encrypt(data)
        return nil if data.nil?

        cipher = OpenSSL::Cipher.new('aes-256-gcm')
        cipher.encrypt
        cipher.key = encryption_key
        iv = cipher.random_iv

        encrypted = cipher.update(data.to_s) + cipher.final
        tag = cipher.auth_tag

        Base64.strict_encode64(iv + tag + encrypted)
      end

      def decrypt(encrypted_data)
        return nil if encrypted_data.nil?

        data = Base64.strict_decode64(encrypted_data)

        cipher = OpenSSL::Cipher.new('aes-256-gcm')
        cipher.decrypt
        cipher.key = encryption_key

        iv = data[0, 12]
        tag = data[12, 16]
        encrypted = data[28..]

        cipher.iv = iv
        cipher.auth_tag = tag

        cipher.update(encrypted) + cipher.final
      rescue OpenSSL::Cipher::CipherError, ArgumentError => e
        Rails.logger.error("Decryption failed: #{e.message}")
        nil
      end

      private

      def encryption_key
        key = ENV['ENCRYPTION_KEY'] || Rails.application.credentials.encryption_key
        raise 'Encryption key not configured' if key.blank?

        # Ensure 32 bytes for AES-256
        Digest::SHA256.digest(key)
      end
    end
  end
end
```

### Security Audit Job
Create `backend/app/jobs/security_audit_job.rb`:
```ruby
class SecurityAuditJob < ApplicationJob
  queue_as :low

  def perform
    audit_results = {
      timestamp: Time.current,
      checks: []
    }

    # Check for users without recent password changes (if applicable)
    audit_results[:checks] << check_password_age

    # Check for unusual login patterns
    audit_results[:checks] << check_login_patterns

    # Check for rate limit violations
    audit_results[:checks] << check_rate_limit_violations

    # Check for failed authentication attempts
    audit_results[:checks] << check_failed_auth_attempts

    # Check for sensitive data exposure
    audit_results[:checks] << check_sensitive_data_logs

    # Store audit results
    SecurityAuditLog.create!(
      audit_type: 'scheduled',
      results: audit_results,
      status: audit_results[:checks].all? { |c| c[:status] == 'pass' } ? 'pass' : 'warning'
    )

    # Alert if issues found
    alert_security_team(audit_results) if audit_results[:checks].any? { |c| c[:status] == 'fail' }
  end

  private

  def check_password_age
    # Placeholder - implement based on auth system
    { name: 'password_age', status: 'pass', details: 'Using JWT authentication' }
  end

  def check_login_patterns
    suspicious_ips = REDIS.keys('rate_limit:auth:ip:*').select do |key|
      REDIS.get(key).to_i > 10
    end

    {
      name: 'login_patterns',
      status: suspicious_ips.any? ? 'warning' : 'pass',
      details: "#{suspicious_ips.length} IPs with multiple auth attempts"
    }
  end

  def check_rate_limit_violations
    violations = REDIS.keys('rate_limit:*').count do |key|
      REDIS.get(key).to_i >= 100
    end

    {
      name: 'rate_limits',
      status: violations > 10 ? 'warning' : 'pass',
      details: "#{violations} rate limit violations in last hour"
    }
  end

  def check_failed_auth_attempts
    failed_count = REDIS.get('auth:failed:count').to_i

    {
      name: 'failed_auth',
      status: failed_count > 100 ? 'warning' : 'pass',
      details: "#{failed_count} failed auth attempts today"
    }
  end

  def check_sensitive_data_logs
    # Check if sensitive data appears in logs
    log_file = Rails.root.join('log', "#{Rails.env}.log")
    return { name: 'sensitive_logs', status: 'pass', details: 'Log file not found' } unless File.exist?(log_file)

    sensitive_patterns = [
      /password["\s:=]+\w+/i,
      /api_key["\s:=]+\w+/i,
      /secret["\s:=]+\w+/i
    ]

    recent_logs = `tail -1000 #{log_file}`
    found = sensitive_patterns.any? { |p| recent_logs.match?(p) }

    {
      name: 'sensitive_logs',
      status: found ? 'fail' : 'pass',
      details: found ? 'Potential sensitive data in logs' : 'No sensitive data found'
    }
  end

  def alert_security_team(results)
    # Send alert via email, Slack, or PagerDuty
    Rails.logger.warn("Security audit found issues: #{results.to_json}")
  end
end
```

### Security Audit Log Migration
Create `backend/db/migrate/xxx_create_security_audit_logs.rb`:
```ruby
class CreateSecurityAuditLogs < ActiveRecord::Migration[7.0]
  def change
    create_table :security_audit_logs do |t|
      t.string :audit_type, null: false
      t.jsonb :results, default: {}
      t.string :status
      t.timestamps
    end

    add_index :security_audit_logs, :created_at
    add_index :security_audit_logs, :status
  end
end
```

### Environment Variables for Security
Add to `backend/.env.example`:
```
# Security
ENCRYPTION_KEY=your-32-character-encryption-key
ADMIN_TOKEN=secure-admin-token
JWT_SECRET_KEY=your-jwt-secret-key

# Allowed Origins
FRONTEND_URL=https://app.nerdy.com

# Rate Limiting
RATE_LIMIT_ENABLED=true
```

---

## Run Tests

```bash
# Backend
cd backend
bundle exec rspec --format documentation
bundle exec rspec --coverage

# Frontend
cd frontend
npm run test
npm run test:coverage
```

---

## Validation Checklist

### Testing
- [ ] RSpec runs all tests successfully
- [ ] Backend coverage >80%
- [ ] Vitest runs all tests successfully
- [ ] Frontend coverage >80%
- [ ] VCR cassettes created for external API calls
- [ ] All factories create valid records

### Security
- [ ] Input sanitization prevents XSS
- [ ] SQL injection patterns are blocked
- [ ] Rate limiting works correctly
- [ ] Security headers are set
- [ ] CORS configured correctly
- [ ] JWT validation is secure
- [ ] Encryption service works
- [ ] Security audit job runs
- [ ] No sensitive data in logs

Execute this entire implementation.
