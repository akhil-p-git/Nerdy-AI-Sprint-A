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


