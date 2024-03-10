# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: 'The sqlbook team <noreply@sqlbook.com>'
  layout 'mailer'
end
