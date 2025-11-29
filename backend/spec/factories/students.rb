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


