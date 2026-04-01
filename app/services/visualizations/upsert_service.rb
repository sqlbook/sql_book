# frozen_string_literal: true

module Visualizations
  class UpsertService
    Result = Struct.new(:success?, :visualization, :code, :message, keyword_init: true)

    def initialize(query:, workspace:, attributes:)
      @query = query
      @workspace = workspace
      @attributes = attributes.to_h.deep_stringify_keys
    end

    def call
      chart_type = normalized_chart_type
      return chart_type_required_failure if chart_type.blank?
      return invalid_chart_type_failure unless valid_chart_type?(chart_type)

      visualization = persist_visualization!(chart_type:)

      Result.new(success?: true, visualization:, code: 'visualization.saved', message: nil)
    rescue ActiveRecord::RecordInvalid
      failure(code: 'visualization.invalid', message: visualization.errors.full_messages.to_sentence)
    end

    private

    attr_reader :query, :workspace, :attributes

    def normalized_chart_type
      attributes['chart_type'].to_s.strip
    end

    def normalized_hash(value)
      return nil if value.nil?

      compact_blank_values(value.to_h.deep_stringify_keys)
    end

    def resolved_appearance_config(mode:, visualization:)
      direct_value = normalized_hash(attributes["appearance_config_#{mode}"])
      return direct_value if direct_value

      editor_params = attributes.fetch("appearance_editor_#{mode}", {}).to_h.symbolize_keys
      raw_json = attributes["appearance_raw_json_#{mode}"]
      built_value = ThemeFormBuilder.build(
        theme_json: visualization.appearance_config_for(mode:),
        editor_params:,
        raw_json:
      )

      compact_blank_values(built_value.deep_stringify_keys)
    end

    def resolved_theme_reference
      reference = attributes['theme_reference'].to_s.strip
      return reference if reference.present?

      workspace.default_visualization_theme&.reference_key || SystemTheme::REFERENCE_KEY
    end

    def persist_visualization!(chart_type:)
      visualization = query.visualization || query.build_visualization
      visualization.assign_attributes(visualization_attributes(chart_type:, visualization:))
      visualization.save!
      visualization
    end

    def chart_type_required_failure
      failure(
        code: 'visualization.chart_type_required',
        message: I18n.t('app.workspaces.visualizations.errors.chart_type_required')
      )
    end

    def invalid_chart_type_failure
      failure(
        code: 'visualization.invalid_chart_type',
        message: I18n.t('app.workspaces.visualizations.errors.invalid_chart_type')
      )
    end

    def valid_chart_type?(chart_type)
      ChartRegistry.types.include?(chart_type)
    end

    def visualization_attributes(chart_type:, visualization:)
      {
        chart_type:,
        theme_reference: resolved_theme_reference,
        data_config: normalized_hash(attributes['data_config']) || visualization.data_config,
        appearance_config_dark: resolved_appearance_config(mode: :dark, visualization:),
        appearance_config_light: resolved_appearance_config(mode: :light, visualization:),
        other_config: normalized_hash(attributes['other_config']) || visualization.other_config
      }
    end

    def failure(code:, message:)
      Result.new(success?: false, visualization: nil, code:, message:)
    end

    def compact_blank_values(value)
      return compact_hash(value) if value.is_a?(Hash)
      return value.map { |nested| compact_blank_values(nested) }.compact_blank if value.is_a?(Array)

      value
    end

    def compact_hash(value)
      value.each_with_object({}) do |(key, nested), memo|
        compacted = compact_blank_values(nested)
        next if compacted.respond_to?(:blank?) ? compacted.blank? : compacted.nil?

        memo[key] = compacted
      end
    end
  end
end
