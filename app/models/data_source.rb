# frozen_string_literal: true

class DataSource < ApplicationRecord
  belongs_to :workspace

  # Ensure the data source URL is unique
  validates :url, uniqueness: true

  # Ensure the data source URL is a valid URI
  validates :url, format: { with: URI::DEFAULT_PARSER.make_regexp, message: I18n.t('models.data_source.is_not_valid') }

  normalizes :url, with: ->(url) { format_as_url_origin(url) }

  has_many :queries, dependent: :destroy

  has_many :clicks,
           dependent: :destroy_async,
           primary_key: :external_uuid,
           foreign_key: :data_source_uuid

  has_many :page_views,
           dependent: :destroy_async,
           primary_key: :external_uuid,
           foreign_key: :data_source_uuid

  has_many :sessions,
           dependent: :destroy_async,
           primary_key: :external_uuid,
           foreign_key: :data_source_uuid

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
