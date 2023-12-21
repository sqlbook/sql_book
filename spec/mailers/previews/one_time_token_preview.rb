# frozen_string_literal: true

# Preview all emails at http://localhost:3000/rails/mailers/one_time_token
class OneTimeTokenPreview < ActionMailer::Preview
  def login
    OneTimeTokenMailer.login(email: 'email@example.com', token: '123456')
  end

  def signup
    OneTimeTokenMailer.signup(email: 'email@example.com', token: '123456')
  end
end
