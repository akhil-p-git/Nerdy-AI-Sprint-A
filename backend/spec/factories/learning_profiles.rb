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


