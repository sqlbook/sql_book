# frozen_string_literal: true

class AccountMailer < ApplicationMailer
  def verify_email_change(user:, token:)
    @user = user
    @current_email = user.email
    @new_email = user.pending_email
    @verification_url = app_verify_email_account_settings_url(token:)

    mail(to: user.email, subject: I18n.t('mailers.account.subjects.verify_email_change'))
  end
end
