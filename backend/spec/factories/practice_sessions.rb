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


