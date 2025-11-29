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


