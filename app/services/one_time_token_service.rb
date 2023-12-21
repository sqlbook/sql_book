# frozen_string_literal: true

class OneTimeTokenService
  def initialize(email:, auth_type:)
    @email = email
    @auth_type = auth_type
  end

  def create!
    return if exists?

    one_time_token = OneTimeToken.create!(email:, token:)
    send_token_email!(token: one_time_token.token)
    one_time_token
  end

  def verify(token:)
    one_time_token = OneTimeToken.find_by(email:)

    if one_time_token&.token == token
      destoy!
      true
    else
      false
    end
  end

  private

  attr_reader :email, :auth_type

  def destoy!
    OneTimeToken.find_by(email:)&.destroy
  end

  def token
    rand(100_000...999_999)
  end

  def exists?
    OneTimeToken.exists?(email:)
  end

  def send_token_email!(token:)
    if auth_type == :login
      OneTimeTokenMailer.login(email:, token:).deliver_now
    else
      OneTimeTokenMailer.signup(email:, token:).deliver_now
    end
  end
end
