# Nerdy AI Study Companion

An AI-powered study companion that exists between tutoring sessions, creating a continuous learning relationship with students.

## Features

- **AI Chat Interface** - Natural language Q&A with context from past sessions
- **Adaptive Practice Engine** - Personalized quizzes and flashcards
- **Progress Tracking** - Learning goals and milestone tracking
- **Tutor Handoff** - Seamless escalation to human tutors when needed

## Tech Stack

- **Frontend:** React 19, TypeScript, TailwindCSS, Vite
- **Backend:** Ruby on Rails 8, PostgreSQL, Redis
- **AI:** OpenAI API

## Quick Start

### Prerequisites

- Node.js 20+
- Ruby 3.2+
- PostgreSQL 15+ (with pgvector extension)
- Redis

### Frontend Only (Demo Mode)

The frontend can run standalone with mock data:

```bash
cd frontend
npm install
npm run dev
```

Visit http://localhost:3005

### Full Stack Setup

1. **Clone the repo:**
   ```bash
   git clone https://github.com/akhil-p-git/Nerdy-AI-Sprint-A.git
   cd Nerdy-AI-Sprint-A
   ```

2. **Setup Backend:**
   ```bash
   cd backend
   cp .env.example .env
   # Edit .env with your credentials

   bundle install
   rails db:create db:migrate db:seed
   rails server
   ```

3. **Setup Frontend:**
   ```bash
   cd frontend
   npm install
   npm run dev
   ```

4. **Access the app:**
   - Frontend: http://localhost:3005
   - Backend API: http://localhost:3000

## Environment Variables

### Backend (.env)

```bash
# Required
DATABASE_URL=postgres://localhost/nerdy_ai_development
REDIS_URL=redis://localhost:6379/0
OPENAI_API_KEY=sk-...

# Optional
FRONTEND_URL=http://localhost:3005
SENTRY_DSN=
```

### Frontend

The frontend uses mock data by default. To connect to the backend, set:

```bash
VITE_API_URL=http://localhost:3000
```

## Running Tests

```bash
# Frontend tests
cd frontend
npm test

# E2E tests (Playwright)
npm run test:e2e

# Backend tests
cd backend
bundle exec rspec
```

## Project Structure

```
.
├── frontend/          # React SPA
│   ├── src/
│   │   ├── components/   # UI components
│   │   ├── pages/        # Route pages
│   │   ├── hooks/        # Custom React hooks
│   │   └── api/          # API client
│   └── e2e/           # Playwright tests
│
├── backend/           # Rails API
│   ├── app/
│   │   ├── controllers/  # API endpoints
│   │   ├── models/       # ActiveRecord models
│   │   └── services/     # Business logic
│   └── spec/          # RSpec tests
│
└── docs/              # Documentation
    └── PRD.md         # Product Requirements
```

## Product Requirements

See [docs/PRD.md](docs/PRD.md) for full product requirements.

**Key Metrics:**
- Reduce goal-achieved churn from 52% to 40%
- Increase sessions per customer by 15%
- 80% of questions answered without human tutor

## License

Proprietary - Nerdy Inc.
