# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    email { "#{SecureRandom.base36}@email.com" }
  end

  factory :one_time_password do
    email { "#{SecureRandom.base36}@email.com" }
    token { '123456' }
  end

  factory :data_source do
    url { 'https://sqlbook.com' }
    user { create(:user) }
  end
end
