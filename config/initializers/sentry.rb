# frozen_string_literal: true

if Rails.env.production?
  sentry_dsn = ENV['SENTRY_DSN']

  if sentry_dsn.present?
    Sentry.init do |config|
      config.breadcrumbs_logger = [:active_support_logger]
      config.dsn = sentry_dsn
      config.traces_sample_rate = 1.0
    end
  end
end
