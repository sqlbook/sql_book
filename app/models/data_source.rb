# frozen_string_literal: true

class DataSource < ApplicationRecord # rubocop:disable Metrics/ClassLength
  SOURCE_TYPES = {
    first_party_capture: 0,
    postgres: 1
  }.freeze

  STATUSES = {
    pending_setup: 0,
    active: 1,
    error: 2
  }.freeze

  MAX_SELECTED_TABLES = 20
  POSTGRES_DEFAULT_PORT = 5432
  POSTGRES_DEFAULT_SSL_MODE = 'prefer'

  belongs_to :workspace
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

  enum :source_type, SOURCE_TYPES
  enum :status, STATUSES

  store_accessor :config, :host, :port, :database_name, :username, :ssl_mode, :extract_category_values

  normalizes :name, with: ->(value) { value.to_s.strip.presence }
  normalizes :url, with: ->(value) { format_as_url_origin(value) }
  normalizes :host, with: ->(value) { value.to_s.strip.presence }
  normalizes :database_name, with: ->(value) { value.to_s.strip.presence }
  normalizes :username, with: ->(value) { value.to_s.strip.presence }
  normalizes :ssl_mode, with: ->(value) { value.to_s.strip.presence }

  validates :name, presence: true
  validates :url,
            uniqueness: { scope: :workspace_id },
            format: {
              with: URI::DEFAULT_PARSER.make_regexp,
              message: ->(*) { I18n.t('models.data_source.is_not_valid') }
            },
            if: :first_party_capture?

  validates :host, :database_name, :username, presence: true, if: :postgres?
  validates :port,
            numericality: { only_integer: true, greater_than: 0, less_than: 65_536 },
            if: :postgres?

  validate :validate_postgres_password, if: :postgres?
  validate :validate_selected_tables_limit, if: :postgres?

  before_validation :normalize_connector_fields
  before_validation :default_capture_name, if: :first_party_capture?

  def verified?
    verified_at.present?
  end

  def display_name
    name.presence || url.presence || database_name.presence || source_type.humanize
  end

  def capture_source?
    first_party_capture?
  end

  def external_database?
    postgres?
  end

  def selected_tables
    Array(config['selected_tables']).map(&:to_s).compact_blank.uniq
  end

  def selected_tables=(value)
    self.config = config.merge(
      'selected_tables' => Array(value).map(&:to_s).map(&:strip).compact_blank.uniq
    )
  end

  def extract_category_values?
    ActiveModel::Type::Boolean.new.cast(extract_category_values)
  end

  def tables_count
    selected_tables.size
  end

  def connector
    DataSources::ConnectorFactory.build(data_source: self)
  end

  def connection_password
    return nil if encrypted_connection_password.blank?

    self.class.connection_password_encryptor.decrypt_and_verify(encrypted_connection_password)
  rescue ActiveSupport::MessageEncryptor::InvalidMessage
    nil
  end

  def connection_password=(value)
    normalized_value = value.to_s
    @raw_connection_password = normalized_value
    self.encrypted_connection_password = encrypted_password_value(normalized_value)
  end

  def connection_config
    {
      host:,
      port: port.to_i,
      database_name:,
      username:,
      password: connection_password,
      ssl_mode: ssl_mode.presence || POSTGRES_DEFAULT_SSL_MODE,
      extract_category_values: extract_category_values?
    }
  end

  def safe_status_payload
    {
      id:,
      name: display_name,
      source_type:,
      status:,
      last_checked_at:,
      last_error: last_error.presence,
      tables_count:,
      verified_at:
    }.compact
  end

  def self.connection_password_encryptor
    key_generator = ActiveSupport::KeyGenerator.new(Rails.application.secret_key_base)
    secret = key_generator.generate_key('data_source_connection_password', ActiveSupport::MessageEncryptor.key_len)
    ActiveSupport::MessageEncryptor.new(secret)
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

  private

  attr_reader :raw_connection_password

  def normalize_connector_fields
    self.config = (config || {}).deep_stringify_keys
    self.source_type ||= :first_party_capture

    return unless postgres?

    apply_postgres_defaults
  end

  def default_capture_name
    self.name ||= url
  end

  def validate_postgres_password
    password_present = raw_connection_password.present? || encrypted_connection_password.present?
    return if password_present

    errors.add(:connection_password, :blank)
  end

  def validate_selected_tables_limit
    return if selected_tables.size <= MAX_SELECTED_TABLES

    errors.add(:selected_tables, I18n.t('models.data_source.selected_tables_limit', count: MAX_SELECTED_TABLES))
  end

  def encrypted_password_value(password)
    return nil if password.blank?

    self.class.connection_password_encryptor.encrypt_and_sign(password)
  end

  def apply_postgres_defaults
    self.port = port.presence || POSTGRES_DEFAULT_PORT
    self.ssl_mode = ssl_mode.presence || POSTGRES_DEFAULT_SSL_MODE
    self.extract_category_values = ActiveModel::Type::Boolean.new.cast(extract_category_values)
    self.selected_tables = selected_tables
  end
end
