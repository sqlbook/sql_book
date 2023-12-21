# frozen_string_literal: true

# Preview all emails at http://localhost:3000/rails/mailers/one_time_passsword
class OneTimePasswordPreview < ActionMailer::Preview
  def login
    OneTimePasswordMailer.login(email: 'email@example.com', token: '123456')
  end

  def signup
    OneTimePasswordMailer.signup(email: 'email@example.com', token: '123456')
  end
end
