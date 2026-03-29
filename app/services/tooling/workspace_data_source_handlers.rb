# frozen_string_literal: true

module Tooling
  class WorkspaceDataSourceHandlers # rubocop:disable Metrics/ClassLength
    ERROR_CODE_MAP = {
      'selected_tables_required' => 'datasource.selected_tables.required',
      'selected_tables_limit' => 'datasource.selected_tables.limit',
      'invalid_selected_tables' => 'datasource.selected_tables.invalid',
      'connection_failed' => 'datasource.connection.failed'
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

      Result.new(
        status: 'executed',
        code: 'datasource.listed',
        data: { 'data_sources' => payload, 'count' => payload.size },
        fallback_message: data_source_list_fallback(payload:)
      )
    end

    def validate_connection(arguments:)
      validation = DataSources::ConnectionValidationService.new(
        source_type: 'postgres',
        attributes: connection_attributes(arguments:)
      ).call

      if validation.success?
        tables = validation.available_tables
        count = table_count(tables)
        Result.new(
          status: 'executed',
          code: 'datasource.connection.validated',
          data: {
            'checked_at' => validation.checked_at&.iso8601,
            'available_tables' => tables,
            'table_count' => count
          },
          fallback_message: "Connection validated. Found #{count} #{table_label(count)}."
        )
      else
        validation_error(
          code: mapped_error_code(validation.error_code || 'connection_failed'),
          data: { 'available_tables' => validation.available_tables },
          fallback_message: normalized_failure_message(validation.message, default: 'Connection failed.')
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
        port: arguments['port'].presence || DataSource::POSTGRES_DEFAULT_PORT,
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

    def normalized_failure_message(message, default:)
      value = message.to_s.strip
      return default if value.blank?
      return default if value.start_with?('translation missing:')

      value
    end

    def validation_error(code:, data: {}, fallback_message: nil)
      Result.new(status: 'validation_error', code:, data:, fallback_message:)
    end

    def create_postgres_data_source(arguments:)
      DataSources::CreatePostgresDataSourceService.new(
        workspace:,
        attributes: create_attributes(arguments:)
      ).call
    end

    def successful_create_result(result)
      data_source = result.data_source
      Result.new(
        status: 'executed',
        code: 'datasource.created',
        data: {
          'data_source' => serialize_data_source(data_source:),
          'available_tables' => result.available_tables
        },
        fallback_message: "Created data source #{data_source.display_name}."
      )
    end

    def failed_create_result(result)
      validation_error(
        code: mapped_error_code(result.error_code),
        data: {
          'available_tables' => result.available_tables
        },
        fallback_message: normalized_failure_message(result.message,
                                                     default: default_failure_message(result.error_code))
      )
    end

    def mapped_error_code(error_code)
      ERROR_CODE_MAP[error_code.to_s] || "datasource.#{error_code.presence || 'validation_error'}"
    end

    def default_failure_message(error_code)
      case error_code.to_s
      when 'selected_tables_required'
        'Please select at least one table.'
      when 'selected_tables_limit'
        "Please select #{DataSource::MAX_SELECTED_TABLES} tables or fewer."
      when 'invalid_selected_tables'
        'One or more selected tables are invalid.'
      else
        'I could not validate that data source.'
      end
    end

    def data_source_list_fallback(payload:) # rubocop:disable Metrics/AbcSize
      return 'No data sources are connected to this workspace.' if payload.empty?

      lines = payload.map do |data_source|
        line = [
          data_source['name'],
          data_source['source_type'].to_s.humanize,
          data_source['status'].to_s.humanize
        ].join(' - ')
        tables = Array(data_source['selected_tables']).first(6)
        tables.any? ? "#{line}\nTables: #{tables.join(', ')}" : line
      end

      ["Found #{payload.size} data source#{'s' unless payload.size == 1}.", lines.join("\n")].join("\n\n")
    end

    def table_label(count)
      count == 1 ? 'table' : 'tables'
    end
  end
end
