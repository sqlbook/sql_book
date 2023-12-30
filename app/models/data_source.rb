# frozen_string_literal: true

class DataSource < ApplicationRecord
  belongs_to :user

  # Ensure the data source URL is unique
  validates :url, uniqueness: true

  # Ensure the data source URL is a valid URI
  validates :url, format: { with: URI::DEFAULT_PARSER.make_regexp, message: I18n.t('models.data_source.is_not_valid') }

  normalizes :url, with: ->(url) { format_as_url_origin(url) }

  def verified?
    !verified_at.nil?
  end

  def self.format_as_url_origin(url)
    uri = URI(url)

    uri.normalize!

    return unless uri.host
    return unless uri.host.include?('.')

    "https://#{URI(url).host}"
  rescue URI::InvalidURIError
    nil
  end
end
