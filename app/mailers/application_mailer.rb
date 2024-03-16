# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: 'The Sqlbook Team <noreply@sqlbook.com>'
  layout 'mailer'
end
