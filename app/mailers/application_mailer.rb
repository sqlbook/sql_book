# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: 'The sqlbook team <hello@sqlbook.com>'
  layout 'mailer'
end
