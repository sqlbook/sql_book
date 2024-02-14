# frozen_string_literal: true

class OneTimePasswordMailer < ApplicationMailer
  def login(email:, token:)
    @token = token
    @magic_link_params = magic_link_params(email:, token:)
    mail(to: email, subject: I18n.t('mailers.one_time_password.subjects.login'))
  end

  def signup(email:, token:)
    @token = token
    @magic_link_params = magic_link_params(email:, token:)
    mail(to: email, subject: I18n.t('mailers.one_time_password.subjects.signup'))
  end

  private

  def magic_link_params(email:, token:)
    {
      email:,
      one_time_password_1: token[0],
      one_time_password_2: token[1],
      one_time_password_3: token[2],
      one_time_password_4: token[3],
      one_time_password_5: token[4],
      one_time_password_6: token[5]
    }
  end
end
