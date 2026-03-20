# frozen_string_literal: true

module DataSources
  class CreatePostgresDataSourceService
    Result = Struct.new(:success?, :data_source, :available_tables, :error_code, :message, keyword_init: true)

    def initialize(workspace:, attributes:)
      @workspace = workspace
      @attributes = attributes.deep_symbolize_keys
    end

    def call
      validation = ConnectionValidationService.new(source_type: 'postgres', attributes: connection_attributes).call
      return failure(code: validation.error_code, message: validation.message, available_tables: validation.available_tables) unless validation.success?

      selected_tables = normalized_selected_tables
      return failure(code: 'selected_tables_required', message: I18n.t('app.workspaces.data_sources.validation.selected_tables_required'), available_tables: validation.available_tables) if selected_tables.empty?
      if selected_tables.size > DataSource::MAX_SELECTED_TABLES
        return failure(
          code: 'selected_tables_limit',
          message: I18n.t('app.workspaces.data_sources.validation.selected_tables_limit', count: DataSource::MAX_SELECTED_TABLES),
          available_tables: validation.available_tables
        )
      end

      permitted_tables = validation.available_tables.flat_map do |group|
        Array(group[:tables]).map { |table| table[:qualified_name] || [group[:schema], table[:name]].join('.') }
      end
      unless (selected_tables - permitted_tables).empty?
        return failure(code: 'invalid_selected_tables', message: I18n.t('app.workspaces.data_sources.validation.invalid_selected_tables'), available_tables: validation.available_tables)
      end

      data_source = workspace.data_sources.new(
        name: attributes[:name],
        source_type: :postgres,
        status: :active,
        last_checked_at: validation.checked_at,
        last_error: nil,
        config: {
          'host' => connection_attributes[:host],
          'port' => connection_attributes[:port].to_i,
          'database_name' => connection_attributes[:database_name],
          'username' => connection_attributes[:username],
          'ssl_mode' => connection_attributes[:ssl_mode].presence || DataSource::POSTGRES_DEFAULT_SSL_MODE,
          'extract_category_values' => ActiveModel::Type::Boolean.new.cast(connection_attributes[:extract_category_values]),
          'selected_tables' => selected_tables
        }
      )
      data_source.connection_password = connection_attributes[:password]
      data_source.save!

      Result.new(success?: true, data_source:, available_tables: validation.available_tables, error_code: nil, message: nil)
    rescue ActiveRecord::RecordInvalid => e
      failure(code: 'validation_error', message: e.record.errors.full_messages.to_sentence)
    end

    private

    attr_reader :workspace, :attributes

    def connection_attributes
      {
        host: attributes[:host],
        port: attributes[:port],
        database_name: attributes[:database_name],
        username: attributes[:username],
        password: attributes[:password],
        ssl_mode: attributes[:ssl_mode],
        extract_category_values: attributes[:extract_category_values]
      }
    end

    def normalized_selected_tables
      Array(attributes[:selected_tables]).map(&:to_s).map(&:strip).compact_blank.uniq
    end

    def failure(code:, message:, available_tables: [])
      Result.new(success?: false, data_source: nil, available_tables:, error_code: code, message:)
    end
  end
end
