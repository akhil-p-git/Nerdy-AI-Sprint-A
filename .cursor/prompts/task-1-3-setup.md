# One-Shot Prompt: Project Setup, Database Schema & Authentication (Tasks 1-3)

## Context
You are building an **AI Study Companion** for Nerdy - an EdTech tutoring platform. This is a 48-hour AI product sprint. The application must integrate with an existing Rails/React platform.

## Your Mission
Complete these 3 tasks in a single implementation pass:

---

## Task 1: Project Setup and Infrastructure

Create the full project structure with Rails API backend and React TypeScript frontend.

### Backend (Rails API)
```bash
# Create in /backend directory
rails new backend --api --database=postgresql --skip-test
```

**Required setup:**
- Ruby 3.2+ / Rails 7+
- PostgreSQL database
- Redis for caching/ActionCable
- Rack CORS configured for frontend
- Dotenv for environment variables

**Create these files:**
1. `backend/Gemfile` - Add gems: `jwt`, `bcrypt`, `rack-cors`, `redis`, `sidekiq`, `dotenv-rails`, `pg_vector`
2. `backend/config/database.yml` - PostgreSQL config with environment variables
3. `backend/config/initializers/cors.rb` - Allow frontend origin
4. `backend/.env.example` - Template for required env vars

### Frontend (React + TypeScript)
```bash
# Create in /frontend directory
npx create-react-app frontend --template typescript
# OR use Vite:
npm create vite@latest frontend -- --template react-ts
```

**Required setup:**
- React 18+ with TypeScript (strict mode)
- TailwindCSS for styling
- React Query for data fetching
- React Router for navigation
- Axios for API calls

**Create these files:**
1. `frontend/src/api/client.ts` - Axios instance with auth interceptors
2. `frontend/src/contexts/AuthContext.tsx` - Auth state management
3. `frontend/tailwind.config.js` - Tailwind configuration
4. `frontend/.env.example` - API URL template

### Docker Setup
Create `docker-compose.yml` in project root:
```yaml
version: '3.8'
services:
  db:
    image: pgvector/pgvector:pg16
    environment:
      POSTGRES_USER: nerdy
      POSTGRES_PASSWORD: ${DB_PASSWORD:-development}
      POSTGRES_DB: nerdy_ai_companion_development
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

  backend:
    build: ./backend
    depends_on:
      - db
      - redis
    ports:
      - "3000:3000"
    environment:
      DATABASE_URL: postgresql://nerdy:${DB_PASSWORD:-development}@db:5432/nerdy_ai_companion_development
      REDIS_URL: redis://redis:6379/0
    volumes:
      - ./backend:/app

  frontend:
    build: ./frontend
    ports:
      - "5173:5173"
    environment:
      VITE_API_URL: http://localhost:3000
    volumes:
      - ./frontend:/app

volumes:
  postgres_data:
```

Create `backend/Dockerfile` and `frontend/Dockerfile`.

---

## Task 2: Database Schema Design

Create Rails migrations for the AI Study Companion data model.

### Required Tables & Models

**1. Students** (`students`)
```ruby
# db/migrate/xxx_create_students.rb
create_table :students do |t|
  t.string :external_id, null: false, index: { unique: true }  # Nerdy platform ID
  t.string :email, null: false
  t.string :first_name
  t.string :last_name
  t.jsonb :preferences, default: {}
  t.jsonb :learning_style, default: {}
  t.timestamps
end
```

**2. Tutors** (`tutors`)
```ruby
create_table :tutors do |t|
  t.string :external_id, null: false, index: { unique: true }
  t.string :email, null: false
  t.string :first_name
  t.string :last_name
  t.string :subjects, array: true, default: []
  t.timestamps
end
```

**3. Learning Profiles** (`learning_profiles`)
```ruby
create_table :learning_profiles do |t|
  t.references :student, null: false, foreign_key: true
  t.string :subject, null: false
  t.integer :proficiency_level, default: 1  # 1-10
  t.jsonb :strengths, default: []
  t.jsonb :weaknesses, default: []
  t.jsonb :knowledge_gaps, default: []
  t.datetime :last_assessed_at
  t.timestamps

  t.index [:student_id, :subject], unique: true
end
```

**4. Learning Goals** (`learning_goals`)
```ruby
create_table :learning_goals do |t|
  t.references :student, null: false, foreign_key: true
  t.string :subject, null: false
  t.string :title, null: false
  t.text :description
  t.string :target_outcome
  t.date :target_date
  t.integer :status, default: 0  # enum: pending, active, completed, paused
  t.integer :progress_percentage, default: 0
  t.jsonb :milestones, default: []
  t.jsonb :suggested_next_goals, default: []
  t.datetime :completed_at
  t.timestamps
end
add_index :learning_goals, [:student_id, :status]
```

**5. Sessions** (`tutoring_sessions`)
```ruby
create_table :tutoring_sessions do |t|
  t.references :student, null: false, foreign_key: true
  t.references :tutor, foreign_key: true
  t.string :external_session_id, index: true  # Nerdy platform session ID
  t.string :subject
  t.text :summary
  t.jsonb :topics_covered, default: []
  t.jsonb :key_concepts, default: []
  t.text :transcript_url
  t.datetime :started_at
  t.datetime :ended_at
  t.timestamps
end
```

**6. Conversation History** (`conversations` + `messages`)
```ruby
create_table :conversations do |t|
  t.references :student, null: false, foreign_key: true
  t.string :subject
  t.string :status, default: 'active'  # active, archived
  t.jsonb :context, default: {}
  t.timestamps
end

create_table :messages do |t|
  t.references :conversation, null: false, foreign_key: true
  t.string :role, null: false  # user, assistant, system
  t.text :content, null: false
  t.jsonb :metadata, default: {}
  t.timestamps
end
add_index :messages, [:conversation_id, :created_at]
```

**7. Practice Sessions** (`practice_sessions` + `practice_problems`)
```ruby
create_table :practice_sessions do |t|
  t.references :student, null: false, foreign_key: true
  t.references :learning_goal, foreign_key: true
  t.string :subject, null: false
  t.string :session_type  # quiz, flashcards, worksheet
  t.integer :total_problems, default: 0
  t.integer :correct_answers, default: 0
  t.integer :time_spent_seconds, default: 0
  t.jsonb :struggled_topics, default: []
  t.datetime :completed_at
  t.timestamps
end

create_table :practice_problems do |t|
  t.references :practice_session, null: false, foreign_key: true
  t.string :problem_type  # multiple_choice, free_response, flashcard
  t.text :question, null: false
  t.text :correct_answer
  t.jsonb :options, default: []  # for multiple choice
  t.text :student_answer
  t.boolean :is_correct
  t.integer :difficulty_level, default: 5  # 1-10
  t.string :topic
  t.text :explanation
  t.integer :time_spent_seconds
  t.timestamps
end
```

**8. Knowledge Nodes** (`knowledge_nodes`) - For vector storage
```ruby
# Enable pgvector extension first
enable_extension 'vector'

create_table :knowledge_nodes do |t|
  t.references :student, null: false, foreign_key: true
  t.string :source_type  # session, conversation, practice
  t.bigint :source_id
  t.string :subject
  t.string :topic
  t.text :content
  t.vector :embedding, limit: 1536  # OpenAI embedding dimension
  t.jsonb :metadata, default: {}
  t.timestamps
end
add_index :knowledge_nodes, :embedding, using: :ivfflat, opclass: :vector_cosine_ops
```

### Create Models with Associations
Generate all models in `backend/app/models/` with proper:
- Associations (`has_many`, `belongs_to`)
- Validations
- Scopes
- Enums where applicable

---

## Task 3: Authentication System Integration

Implement JWT authentication compatible with Nerdy's existing platform.

### JWT Authentication Service
Create `backend/app/services/jwt_service.rb`:
```ruby
class JwtService
  SECRET_KEY = Rails.application.credentials.jwt_secret_key || ENV['JWT_SECRET_KEY']
  ALGORITHM = 'HS256'

  def self.encode(payload, exp = 24.hours.from_now)
    payload[:exp] = exp.to_i
    JWT.encode(payload, SECRET_KEY, ALGORITHM)
  end

  def self.decode(token)
    decoded = JWT.decode(token, SECRET_KEY, true, algorithm: ALGORITHM)
    HashWithIndifferentAccess.new(decoded.first)
  rescue JWT::DecodeError, JWT::ExpiredSignature => e
    Rails.logger.error("JWT Error: #{e.message}")
    nil
  end
end
```

### Authentication Controller
Create `backend/app/controllers/api/v1/auth_controller.rb`:
```ruby
module Api
  module V1
    class AuthController < ApplicationController
      skip_before_action :authenticate_request, only: [:login, :refresh]

      # POST /api/v1/auth/login
      # Validates token from Nerdy platform and creates local session
      def login
        # Accept Nerdy platform token and validate
        nerdy_token = params[:nerdy_token]

        # Validate with Nerdy platform (mock for now)
        user_data = validate_nerdy_token(nerdy_token)

        if user_data
          student = Student.find_or_create_by(external_id: user_data[:id]) do |s|
            s.email = user_data[:email]
            s.first_name = user_data[:first_name]
            s.last_name = user_data[:last_name]
          end

          token = JwtService.encode(student_id: student.id)
          refresh_token = JwtService.encode({ student_id: student.id }, 7.days.from_now)

          render json: {
            token: token,
            refresh_token: refresh_token,
            student: StudentSerializer.new(student)
          }
        else
          render json: { error: 'Invalid credentials' }, status: :unauthorized
        end
      end

      # POST /api/v1/auth/refresh
      def refresh
        refresh_token = params[:refresh_token]
        payload = JwtService.decode(refresh_token)

        if payload && payload[:student_id]
          student = Student.find(payload[:student_id])
          token = JwtService.encode(student_id: student.id)
          render json: { token: token }
        else
          render json: { error: 'Invalid refresh token' }, status: :unauthorized
        end
      end

      # GET /api/v1/auth/me
      def me
        render json: StudentSerializer.new(current_student)
      end

      private

      def validate_nerdy_token(token)
        # TODO: Integrate with actual Nerdy platform API
        # For now, mock validation
        return nil if token.blank?

        # Mock user data - replace with actual API call
        {
          id: "nerdy_#{SecureRandom.hex(8)}",
          email: "student@example.com",
          first_name: "Test",
          last_name: "Student"
        }
      end
    end
  end
end
```

### Authentication Concern
Create `backend/app/controllers/concerns/authenticatable.rb`:
```ruby
module Authenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_request
  end

  private

  def authenticate_request
    token = extract_token
    payload = JwtService.decode(token)

    if payload && payload[:student_id]
      @current_student = Student.find_by(id: payload[:student_id])
      render json: { error: 'User not found' }, status: :unauthorized unless @current_student
    else
      render json: { error: 'Invalid or expired token' }, status: :unauthorized
    end
  end

  def extract_token
    header = request.headers['Authorization']
    header&.split(' ')&.last
  end

  def current_student
    @current_student
  end
end
```

### Base Application Controller
Update `backend/app/controllers/application_controller.rb`:
```ruby
class ApplicationController < ActionController::API
  include Authenticatable

  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity

  private

  def not_found(exception)
    render json: { error: exception.message }, status: :not_found
  end

  def unprocessable_entity(exception)
    render json: { error: exception.record.errors.full_messages }, status: :unprocessable_entity
  end
end
```

### Routes
Update `backend/config/routes.rb`:
```ruby
Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      # Authentication
      post 'auth/login', to: 'auth#login'
      post 'auth/refresh', to: 'auth#refresh'
      get 'auth/me', to: 'auth#me'

      # Future endpoints
      resources :students, only: [:show, :update]
      resources :learning_profiles, only: [:index, :show, :update]
      resources :learning_goals
      resources :conversations do
        resources :messages, only: [:index, :create]
      end
      resources :practice_sessions do
        resources :practice_problems, only: [:index, :show, :update]
      end
    end
  end

  # Health check
  get '/health', to: proc { [200, {}, ['ok']] }
end
```

### Frontend Auth Context
Create `frontend/src/contexts/AuthContext.tsx`:
```typescript
import React, { createContext, useContext, useState, useEffect, ReactNode } from 'react';
import { api } from '../api/client';

interface Student {
  id: number;
  email: string;
  firstName: string;
  lastName: string;
}

interface AuthContextType {
  student: Student | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  login: (nerdyToken: string) => Promise<void>;
  logout: () => void;
  refreshToken: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [student, setStudent] = useState<Student | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    const token = localStorage.getItem('token');
    if (token) {
      fetchCurrentUser();
    } else {
      setIsLoading(false);
    }
  }, []);

  const fetchCurrentUser = async () => {
    try {
      const response = await api.get('/api/v1/auth/me');
      setStudent(response.data.student);
    } catch (error) {
      localStorage.removeItem('token');
      localStorage.removeItem('refreshToken');
    } finally {
      setIsLoading(false);
    }
  };

  const login = async (nerdyToken: string) => {
    const response = await api.post('/api/v1/auth/login', { nerdy_token: nerdyToken });
    localStorage.setItem('token', response.data.token);
    localStorage.setItem('refreshToken', response.data.refresh_token);
    setStudent(response.data.student);
  };

  const logout = () => {
    localStorage.removeItem('token');
    localStorage.removeItem('refreshToken');
    setStudent(null);
  };

  const refreshToken = async () => {
    const refresh = localStorage.getItem('refreshToken');
    if (refresh) {
      const response = await api.post('/api/v1/auth/refresh', { refresh_token: refresh });
      localStorage.setItem('token', response.data.token);
    }
  };

  return (
    <AuthContext.Provider value={{
      student,
      isAuthenticated: !!student,
      isLoading,
      login,
      logout,
      refreshToken
    }}>
      {children}
    </AuthContext.Provider>
  );
}

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) throw new Error('useAuth must be used within AuthProvider');
  return context;
};
```

### Frontend API Client
Create `frontend/src/api/client.ts`:
```typescript
import axios from 'axios';

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:3000';

export const api = axios.create({
  baseURL: API_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Request interceptor - add auth token
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// Response interceptor - handle token refresh
api.interceptors.response.use(
  (response) => response,
  async (error) => {
    const originalRequest = error.config;

    if (error.response?.status === 401 && !originalRequest._retry) {
      originalRequest._retry = true;

      const refreshToken = localStorage.getItem('refreshToken');
      if (refreshToken) {
        try {
          const response = await axios.post(`${API_URL}/api/v1/auth/refresh`, {
            refresh_token: refreshToken
          });
          localStorage.setItem('token', response.data.token);
          originalRequest.headers.Authorization = `Bearer ${response.data.token}`;
          return api(originalRequest);
        } catch (refreshError) {
          localStorage.removeItem('token');
          localStorage.removeItem('refreshToken');
          window.location.href = '/login';
        }
      }
    }
    return Promise.reject(error);
  }
);
```

---

## File Structure to Create

```
NerdyAISprint/
├── docker-compose.yml
├── .gitignore
├── README.md
├── backend/
│   ├── Dockerfile
│   ├── Gemfile
│   ├── .env.example
│   ├── config/
│   │   ├── database.yml
│   │   ├── routes.rb
│   │   └── initializers/
│   │       └── cors.rb
│   ├── app/
│   │   ├── controllers/
│   │   │   ├── application_controller.rb
│   │   │   ├── concerns/
│   │   │   │   └── authenticatable.rb
│   │   │   └── api/
│   │   │       └── v1/
│   │   │           └── auth_controller.rb
│   │   ├── models/
│   │   │   ├── student.rb
│   │   │   ├── tutor.rb
│   │   │   ├── learning_profile.rb
│   │   │   ├── learning_goal.rb
│   │   │   ├── tutoring_session.rb
│   │   │   ├── conversation.rb
│   │   │   ├── message.rb
│   │   │   ├── practice_session.rb
│   │   │   ├── practice_problem.rb
│   │   │   └── knowledge_node.rb
│   │   ├── services/
│   │   │   └── jwt_service.rb
│   │   └── serializers/
│   │       └── student_serializer.rb
│   └── db/
│       └── migrate/
│           ├── 001_create_students.rb
│           ├── 002_create_tutors.rb
│           ├── 003_create_learning_profiles.rb
│           ├── 004_create_learning_goals.rb
│           ├── 005_create_tutoring_sessions.rb
│           ├── 006_create_conversations.rb
│           ├── 007_create_messages.rb
│           ├── 008_create_practice_sessions.rb
│           ├── 009_create_practice_problems.rb
│           └── 010_create_knowledge_nodes.rb
└── frontend/
    ├── Dockerfile
    ├── .env.example
    ├── package.json
    ├── tsconfig.json
    ├── tailwind.config.js
    ├── vite.config.ts
    └── src/
        ├── App.tsx
        ├── main.tsx
        ├── api/
        │   └── client.ts
        ├── contexts/
        │   └── AuthContext.tsx
        ├── components/
        │   └── ProtectedRoute.tsx
        └── pages/
            └── Login.tsx
```

---

## Validation Checklist

After implementation, verify:
- [ ] `docker-compose up` starts all services
- [ ] `rails db:create db:migrate` runs successfully
- [ ] All 10 database tables are created
- [ ] `POST /api/v1/auth/login` returns JWT token
- [ ] `GET /api/v1/auth/me` returns current user with valid token
- [ ] `GET /api/v1/auth/me` returns 401 without token
- [ ] Frontend builds without TypeScript errors
- [ ] Auth context properly manages login state

---

## Environment Variables Required

**Backend (.env):**
```
DATABASE_URL=postgresql://nerdy:development@localhost:5432/nerdy_ai_companion_development
REDIS_URL=redis://localhost:6379/0
JWT_SECRET_KEY=your-super-secret-key-change-in-production
RAILS_ENV=development
```

**Frontend (.env):**
```
VITE_API_URL=http://localhost:3000
```

---

Execute this entire setup. Create all files, run migrations, and ensure the authentication flow works end-to-end.
