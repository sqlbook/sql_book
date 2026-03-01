# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: 'The Sqlbook Team <noreply@sqlbook.com>'
  layout 'mailer'

  private

  def with_recipient_locale(recipient: nil, email: nil, fallback_locale: nil, &)
    locale = resolved_locale(recipient:, email:, fallback_locale:)
    I18n.with_locale(locale, &)
  end

  def resolved_locale(recipient:, email:, fallback_locale:)
    requested_locale = recipient&.preferred_locale || user_locale_by_email(email:) || fallback_locale
    locale = requested_locale.to_s.downcase
    return locale if User::SUPPORTED_LOCALES.include?(locale)

    I18n.default_locale.to_s
  end

  def user_locale_by_email(email:)
    return nil if email.blank?

    User.find_by(email: email.to_s.downcase)&.preferred_locale
  end
end
