# frozen_string_literal: true

module DataSources
  class UpdatePostgresDataSourceService # rubocop:disable Metrics/ClassLength
    Result = Struct.new(:success?, :data_source, :available_tables, :error_code, :message, keyword_init: true)

    def initialize(data_source:, attributes:)
      @data_source = data_source
      @attributes = attributes.deep_symbolize_keys
    end

    def call
      validation = validate_connection
      return validation_failure(validation) unless validation.success?

      selected_tables = normalized_selected_tables
      failure = validate_selected_tables(selected_tables, validation.available_tables)
      return failure if failure

      update_data_source(selected_tables:, checked_at: validation.checked_at)

      success(available_tables: validation.available_tables)
    rescue ActiveRecord::RecordInvalid => e
      failure(code: 'validation_error', message: e.record.errors.full_messages.to_sentence)
    end

    private

    attr_reader :data_source, :attributes

    def connection_attributes
      {
        host: attributes[:host],
        port: attributes[:port],
        database_name: attributes[:database_name],
        username: attributes[:username],
        password: effective_password,
        ssl_mode: attributes[:ssl_mode],
        extract_category_values: attributes[:extract_category_values]
      }
    end

    def normalized_selected_tables
      Array(attributes[:selected_tables]).map(&:to_s).map(&:strip).compact_blank.uniq
    end

    def effective_password
      attributes[:password].presence || data_source.connection_password
    end

    def validate_connection
      ConnectionValidationService.new(
        source_type: 'postgres',
        attributes: connection_attributes
      ).call
    end

    def validation_failure(validation)
      failure(
        code: validation.error_code,
        message: validation.message,
        available_tables: validation.available_tables
      )
    end

    def validate_selected_tables(selected_tables, available_tables)
      return selected_tables_required_failure(available_tables) if selected_tables.empty?
      return selected_tables_limit_failure(available_tables) if selected_tables.size > DataSource::MAX_SELECTED_TABLES
      if invalid_selected_tables?(selected_tables, available_tables)
        return invalid_selected_tables_failure(available_tables)
      end

      nil
    end

    def selected_tables_required_failure(available_tables)
      failure(
        code: 'selected_tables_required',
        message: I18n.t('app.workspaces.data_sources.validation.selected_tables_required'),
        available_tables:
      )
    end

    def selected_tables_limit_failure(available_tables)
      failure(
        code: 'selected_tables_limit',
        message: I18n.t(
          'app.workspaces.data_sources.validation.selected_tables_limit',
          count: DataSource::MAX_SELECTED_TABLES
        ),
        available_tables:
      )
    end

    def invalid_selected_tables_failure(available_tables)
      failure(
        code: 'invalid_selected_tables',
        message: I18n.t('app.workspaces.data_sources.validation.invalid_selected_tables'),
        available_tables:
      )
    end

    def invalid_selected_tables?(selected_tables, available_tables)
      (selected_tables - permitted_tables(available_tables)).any?
    end

    def permitted_tables(available_tables)
      available_tables.flat_map do |group|
        Array(group[:tables]).map do |table|
          table[:qualified_name] || [group[:schema], table[:name]].join('.')
        end
      end
    end

    def update_data_source(selected_tables:, checked_at:)
      data_source.assign_attributes(
        status: :active,
        last_checked_at: checked_at,
        last_error: nil,
        config: updated_config(selected_tables)
      )
      data_source.connection_password = attributes[:password] if attributes[:password].present?
      data_source.save!
    end

    def updated_config(selected_tables)
      {
        'host' => connection_attributes[:host],
        'port' => connection_attributes[:port].to_i,
        'database_name' => connection_attributes[:database_name],
        'username' => connection_attributes[:username],
        'ssl_mode' => connection_attributes[:ssl_mode].presence || DataSource::POSTGRES_DEFAULT_SSL_MODE,
        'extract_category_values' => extract_category_values_flag,
        'selected_tables' => selected_tables
      }
    end

    def extract_category_values_flag
      ActiveModel::Type::Boolean.new.cast(connection_attributes[:extract_category_values])
    end

    def success(available_tables:)
      Result.new(
        success?: true,
        data_source:,
        available_tables:,
        error_code: nil,
        message: nil
      )
    end

    def failure(code:, message:, available_tables: [])
      Result.new(success?: false, data_source:, available_tables:, error_code: code, message:)
    end
  end
end
