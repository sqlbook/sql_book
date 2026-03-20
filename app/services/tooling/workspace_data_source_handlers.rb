# frozen_string_literal: true

module Tooling
  class WorkspaceDataSourceHandlers # rubocop:disable Metrics/ClassLength
    FAILURE_MESSAGE_KEYS = {
      'selected_tables_required' => :selected_tables_required,
      'selected_tables_limit' => :selected_tables_limit,
      'invalid_selected_tables' => :invalid_selected_tables,
      'connection_failed' => :connection_failed
    }.freeze

    def initialize(workspace:, actor:)
      @workspace = workspace
      @actor = actor
    end

    def list(arguments:) # rubocop:disable Lint/UnusedMethodArgument
      data_sources = workspace.data_sources
        .includes(:queries)
        .order(Arel.sql(ordering_sql), :name, :id)

      payload = data_sources.map { |data_source| serialize_data_source(data_source:) }
      message = if payload.empty?
                  default_message('data_sources_none')
                else
                  default_message('data_sources_found', count: payload.size)
                end

      executed(message:, data: { 'data_sources' => payload })
    end

    def validate_connection(arguments:)
      validation = DataSources::ConnectionValidationService.new(
        source_type: 'postgres',
        attributes: connection_attributes(arguments:)
      ).call

      if validation.success?
        tables = validation.available_tables
        executed(
          message: default_message('connection_validated', table_count: table_count(tables)),
          data: {
            'checked_at' => validation.checked_at&.iso8601,
            'available_tables' => tables
          }
        )
      else
        validation_error(
          message: normalized_failure_message(
            validation.message,
            'connection_failed',
            default: default_message('connection_failed')
          ),
          data: {
            'available_tables' => validation.available_tables
          }
        )
      end
    end

    def create(arguments:)
      result = create_postgres_data_source(arguments:)
      return successful_create_result(result) if result.success?

      failed_create_result(result)
    end

    private

    attr_reader :workspace, :actor

    def serialize_data_source(data_source:)
      data_source.safe_status_payload
        .transform_keys(&:to_s)
        .merge(
          'selected_tables' => data_source.selected_tables,
          'related_queries_count' => data_source.queries.size
        )
    end

    def ordering_sql
      <<~SQL.squish
        CASE data_sources.source_type
        WHEN #{DataSource.source_types['postgres']} THEN 0
        WHEN #{DataSource.source_types['first_party_capture']} THEN 1
        ELSE 2
        END
      SQL
    end

    def connection_attributes(arguments:)
      {
        host: arguments['host'],
        port: arguments['port'],
        database_name: arguments['database_name'],
        username: arguments['username'],
        password: arguments['password'],
        ssl_mode: arguments['ssl_mode'],
        extract_category_values: arguments['extract_category_values']
      }
    end

    def create_attributes(arguments:)
      connection_attributes(arguments:).merge(
        name: arguments['name'],
        selected_tables: Array(arguments['selected_tables']).map(&:to_s)
      )
    end

    def table_count(groups)
      Array(groups).sum { |group| Array(group[:tables] || group['tables']).size }
    end

    def normalized_failure_message(message, code, default:)
      value = message.to_s.strip
      return default if value.blank?
      return default if value.start_with?('translation missing:')

      translated_failure_message(code) || value
    end

    def default_failure_message(code)
      translated_failure_message(code) || default_message('validation_error')
    end

    def default_message(key, **args)
      I18n.t("app.workspaces.chat.datasource.#{key}", **args)
    end

    def executed(message:, data: {})
      Result.new(status: 'executed', message:, data:, error_code: nil)
    end

    def validation_error(message:, data: {}, code: 'validation_error')
      Result.new(status: 'validation_error', message:, data:, error_code: code)
    end

    def create_postgres_data_source(arguments:)
      DataSources::CreatePostgresDataSourceService.new(
        workspace:,
        attributes: create_attributes(arguments:)
      ).call
    end

    def successful_create_result(result)
      data_source = result.data_source
      executed(
        message: default_message('data_source_created', name: data_source.display_name),
        data: {
          'data_source' => serialize_data_source(data_source:),
          'available_tables' => result.available_tables
        }
      )
    end

    def failed_create_result(result)
      validation_error(
        message: normalized_failure_message(
          result.message,
          result.error_code,
          default: default_failure_message(result.error_code)
        ),
        data: {
          'available_tables' => result.available_tables
        }
      )
    end

    def translated_failure_message(code)
      key = FAILURE_MESSAGE_KEYS[code.to_s]
      return unless key

      return default_message(key, count: DataSource::MAX_SELECTED_TABLES) if key == :selected_tables_limit

      default_message(key)
    end
  end
end
