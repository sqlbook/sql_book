# frozen_string_literal: true

module QueryEditor
  class SaveService # rubocop:disable Metrics/ClassLength
    Result = Struct.new(
      :success?,
      :query,
      :code,
      :message,
      :save_outcome,
      :conflicting_query,
      keyword_init: true
    )

    VisualizationSyncError = Class.new(StandardError) do
      attr_reader :code, :message

      def initialize(code:, message:)
        @code = code
        @message = message
        super(message)
      end
    end

    def initialize(workspace:, actor:, attributes:)
      @workspace = workspace
      @actor = actor
      @attributes = attributes.to_h.deep_stringify_keys
    end

    def call # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      validation_failure = initial_validation_failure
      return validation_failure if validation_failure

      selected_data_source = resolve_data_source
      return selected_data_source if selected_data_source.is_a?(Result)

      DataSources::QuerySafetyGuard.validate!(sql:)

      existing_query = resolve_query
      return existing_query if existing_query.is_a?(Result)

      duplicate_result = duplicate_check_result(query: existing_query, data_source: selected_data_source)
      return duplicate_result if duplicate_result

      return run_required_failure if successful_run_required?(query: existing_query, data_source: selected_data_source)

      persist_query(query: existing_query, data_source: selected_data_source)
    rescue VisualizationSyncError => e
      failure(code: e.code, message: e.message)
    rescue ActiveRecord::RecordInvalid => e
      failure(code: 'query.invalid', message: e.record.errors.full_messages.to_sentence)
    rescue DataSources::Connectors::BaseConnector::QueryError => e
      failure(code: normalized_query_code(e.code), message: e.message)
    end

    private

    attr_reader :workspace, :actor, :attributes

    def resolve_query
      query_id = attributes['query_id'].to_i
      return nil if query_id.zero?

      Query.joins(:data_source)
        .where(data_sources: { workspace_id: workspace.id })
        .find_by(id: query_id) || failure(
          code: 'query.not_found',
          message: I18n.t('app.workspaces.queries.editor.errors.query_not_found')
        )
    end

    def resolve_data_source
      data_source = workspace.data_sources.find_by(id: attributes['data_source_id'].to_i)
      return data_source if data_source.present?

      failure(
        code: 'query.data_source_not_found',
        message: I18n.t('app.workspaces.queries.editor.errors.data_source_not_found')
      )
    end

    def initial_validation_failure
      return sql_required_failure if sql.blank?
      return name_required_failure if name.blank?

      nil
    end

    def assign_query_attributes!(query:, data_source:)
      query.assign_attributes(
        data_source:,
        last_updated_by: actor,
        name:,
        query: sql,
        saved: true,
        query_fingerprint: Queries::Fingerprint.build(data_source_id: data_source.id, sql:)
      )
    end

    def conflicting_saved_query_for(query:, data_source:)
      fingerprint = Queries::Fingerprint.build(data_source_id: data_source.id, sql:)
      return nil if fingerprint.blank?

      scope = Query.where(data_source_id: data_source.id, saved: true, query_fingerprint: fingerprint)
      scope = scope.where.not(id: query.id) if query.present?
      scope.first
    end

    def duplicate_check_result(query:, data_source:)
      conflicting_query = conflicting_saved_query_for(query:, data_source:)
      return if conflicting_query.blank?

      if query.blank?
        reconcile_chat_query_cards!(query: conflicting_query)
        return already_saved(query: conflicting_query)
      end

      duplicate_failure(conflicting_query:)
    end

    def successful_run_required?(query:, data_source:)
      return false unless requires_successful_run?(query:, data_source:)

      !RunToken.valid?(token: attributes['run_token'], data_source_id: data_source.id, sql:)
    end

    def requires_successful_run?(query:, data_source:)
      return true if query.blank?

      query.data_source_id != data_source.id || normalized_sql(query.query) != normalized_sql(sql)
    end

    def normalized_sql(value)
      Queries::Fingerprint.normalize_sql(value)
    end

    def sync_visualizations!(query:)
      configured_payloads(query:).each do |payload|
        chart_type = payload['chart_type'].to_s.strip
        next if chart_type.blank?

        result = Visualizations::UpsertService.new(
          query:,
          workspace:,
          chart_type:,
          attributes: payload
        ).call
        next if result.success?

        raise VisualizationSyncError.new(code: result.code, message: result.message)
      end
    end

    def sync_groups!(query:)
      QueryGroups::SyncService.new(
        query:,
        workspace:,
        names: attributes['group_names']
      ).call
    end

    def configured_payloads(query:)
      payloads = Array(attributes['visualizations']).map { |entry| entry.to_h.deep_stringify_keys }
      configured_chart_types = payloads.filter_map { |entry| entry['chart_type'].to_s.strip.presence }
      query.visualizations.where.not(chart_type: configured_chart_types).find_each(&:destroy!)
      payloads
    end

    def persist_query(query:, data_source:)
      persisted_query = nil

      Query.transaction do
        persisted_query = query || Query.new(author: actor)
        assign_query_attributes!(query: persisted_query, data_source:)
        persisted_query.save!
        sync_groups!(query: persisted_query)
        sync_visualizations!(query: persisted_query)
      end

      reconcile_chat_query_cards!(query: persisted_query) if persisted_query.saved?
      success(query: persisted_query.reload, save_outcome: query.present? ? 'updated' : 'created')
    end

    def already_saved(query:)
      Result.new(
        success?: true,
        query:,
        code: 'query.already_saved',
        message: nil,
        save_outcome: 'already_saved',
        conflicting_query: nil
      )
    end

    def success(query:, save_outcome:)
      Result.new(
        success?: true,
        query:,
        code: save_outcome == 'created' ? 'query.saved' : 'query.updated',
        message: nil,
        save_outcome:,
        conflicting_query: nil
      )
    end

    def duplicate_failure(conflicting_query:)
      Result.new(
        success?: false,
        query: nil,
        code: 'query.duplicate_saved_query',
        message: I18n.t(
          'app.workspaces.queries.editor.errors.duplicate_saved_query',
          name: conflicting_query.name
        ),
        save_outcome: nil,
        conflicting_query:
      )
    end

    def failure(code:, message:)
      Result.new(
        success?: false,
        query: nil,
        code:,
        message:,
        save_outcome: nil,
        conflicting_query: nil
      )
    end

    def sql_required_failure
      failure(
        code: 'query.sql_required',
        message: I18n.t('app.workspaces.queries.editor.errors.sql_required')
      )
    end

    def name_required_failure
      failure(
        code: 'query.name_required',
        message: I18n.t('app.workspaces.queries.editor.errors.name_required')
      )
    end

    def run_required_failure
      failure(
        code: 'query.run_required',
        message: I18n.t('app.workspaces.queries.editor.errors.run_required')
      )
    end

    def sql
      @sql ||= attributes['sql'].to_s.strip
    end

    def name
      @name ||= attributes['name'].to_s.strip.presence
    end

    def reconcile_chat_query_cards!(query:)
      Queries::ChatQueryCardReconciler.new(query:).call
    end

    def normalized_query_code(code)
      return 'query.validation_error' if code.blank?
      return code if code.to_s.include?('.')

      "query.#{code}"
    end
  end # rubocop:enable Metrics/ClassLength
end
