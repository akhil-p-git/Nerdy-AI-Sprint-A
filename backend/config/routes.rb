Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      # Authentication
      post 'auth/login', to: 'auth#login'
      post 'auth/refresh', to: 'auth#refresh'
      get 'auth/me', to: 'auth#me'

      # Learning Profiles & Goals
      resources :learning_profiles, only: [:index, :show, :update] do
        collection do
          get :summary
        end
      end

      resources :learning_goals do
        member do
          get :suggestions
          post :evaluate_completion
          post :milestones, to: 'learning_goals#add_milestone'
          put 'milestones/:milestone_id', to: 'learning_goals#update_milestone'
        end
      end

      # Stats & Activities
      get 'stats', to: 'stats#index'
      get 'stats/weekly', to: 'stats#weekly'
      get 'activities', to: 'activities#index'

      resources :conversations do
        resources :messages, only: [:index, :create]
        member do
          post :messages, to: 'conversations#send_message'
        end
      end
      resources :practice_sessions do
        resources :practice_problems, only: [:index, :show, :update]
        member do
          post :submit, to: 'practice_sessions#submit_answer'
          post :complete
        end
        collection do
          get :review
        end
      end

      # Engagement & Retention
      resources :student_events, only: [:index] do
        collection do
          post :acknowledge
        end
      end

      # Tutor Handoffs
      resources :handoffs, only: [:create, :show] do
        member do
          post :book
        end
      end

      # Tutor Briefs (tutor-facing)
      resources :tutor_briefs, only: [:index, :show] do
        collection do
          post :generate
        end
      end

      # Parent Dashboard
      namespace :parent do
        get 'dashboard', to: 'dashboard#index'
        get 'dashboard/student/:id', to: 'dashboard#student_detail'
        get 'dashboard/weekly_report/:student_id', to: 'dashboard#weekly_report_detail'
      end

      # Admin Analytics
      namespace :admin do
        get 'analytics/overview', to: 'analytics#overview'
        get 'analytics/engagement', to: 'analytics#engagement'
        get 'analytics/learning', to: 'analytics#learning'
      end
    end
  end

  # ActionCable mount
  mount ActionCable.server => '/cable'

  # Health check
  get '/health', to: proc { [200, {}, ['ok']] }
end
