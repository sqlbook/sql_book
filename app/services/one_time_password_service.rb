# frozen_string_literal: true

class OneTimePasswordService
  def initialize(email:, auth_type:)
    @email = email
    @auth_type = auth_type
  end

  def create!
    return if exists?

    one_time_password = OneTimePassword.create!(email:, token:)
    send_token_email!(token: one_time_password.token)
    one_time_password
  end

  def verify(token:)
    one_time_password = OneTimePassword.find_by(email:)

    if one_time_password&.token == token
      destoy!
      true
    else
      false
    end
  end

  private

  attr_reader :email, :auth_type

  def destoy!
    OneTimePassword.find_by(email:)&.destroy
  end

  def token
    rand(100_000...999_999)
  end

  def exists?
    OneTimePassword.exists?(email:)
  end

  def send_token_email!(token:)
    if auth_type == :login
      OneTimePasswordMailer.login(email:, token:).deliver_now
    else
      OneTimePasswordMailer.signup(email:, token:).deliver_now
    end
  end
end
