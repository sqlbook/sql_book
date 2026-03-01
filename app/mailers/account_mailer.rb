# frozen_string_literal: true

class AccountMailer < ApplicationMailer
  def verify_email_change(user:, token:)
    @user = user
    @current_email = user.email
    @new_email = user.pending_email
    @verification_url = app_verify_email_account_settings_url(token:)

    with_recipient_locale(recipient: user) do
      mail(to: user.email, subject: I18n.t('mailers.account.subjects.verify_email_change'))
    end
  end

  def account_deletion_confirmed(user_email:, fallback_locale: nil)
    with_recipient_locale(email: user_email, fallback_locale:) do
      mail(to: user_email, subject: I18n.t('mailers.account.subjects.account_deletion_confirmed'))
    end
  end
end
