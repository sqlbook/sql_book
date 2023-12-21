# frozen_string_literal: true

class OneTimePasswordMailer < ApplicationMailer
  def login(email:, token:)
    @token = token
    mail(to: email, subject: I18n.t('mailers.one_time_password.subjects.login'))
  end

  def signup(email:, token:)
    @token = token
    mail(to: email, subject: I18n.t('mailers.one_time_password.subjects.signup'))
  end
end
