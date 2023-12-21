# frozen_string_literal: true

class OneTimeTokenMailer < ApplicationMailer
  def login(email:, token:)
    @token = token
    mail(to: email, subject: I18n.t('mailers.one_time_token.subjects.login'))
  end

  def signup(email:, token:)
    @token = token
    mail(to: email, subject: I18n.t('mailers.one_time_token.subjects.signup'))
  end
end
