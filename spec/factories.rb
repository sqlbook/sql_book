# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    email { "#{SecureRandom.base36}@email.com" }
  end

  factory :one_time_password do
    email { "#{SecureRandom.base36}@email.com" }
    token { '123456' }
  end
end
