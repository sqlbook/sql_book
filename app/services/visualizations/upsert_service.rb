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
      chart_type = attributes['chart_type'].to_s.strip
      return failure(code: 'visualization.chart_type_required', message: I18n.t('app.workspaces.visualizations.errors.chart_type_required')) if chart_type.blank?
      return failure(code: 'visualization.invalid_chart_type', message: I18n.t('app.workspaces.visualizations.errors.invalid_chart_type')) unless ChartRegistry.types.include?(chart_type)

      visualization = query.visualization || query.build_visualization
      visualization.assign_attributes(
        chart_type:,
        theme_reference: resolved_theme_reference,
        data_config: normalized_hash(attributes['data_config']) || visualization.data_config,
        appearance_config_dark: resolved_appearance_config(mode: :dark, visualization:),
        appearance_config_light: resolved_appearance_config(mode: :light, visualization:),
        other_config: normalized_hash(attributes['other_config']) || visualization.other_config
      )
      visualization.save!

      Result.new(success?: true, visualization:, code: 'visualization.saved', message: nil)
    rescue ActiveRecord::RecordInvalid
      failure(code: 'visualization.invalid', message: visualization.errors.full_messages.to_sentence)
    end

    private

    attr_reader :query, :workspace, :attributes

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

    def failure(code:, message:)
      Result.new(success?: false, visualization: nil, code:, message:)
    end

    def compact_blank_values(value)
      case value
      when Hash
        value.each_with_object({}) do |(key, nested), memo|
          compacted = compact_blank_values(nested)
          next if compacted.respond_to?(:blank?) ? compacted.blank? : compacted.nil?

          memo[key] = compacted
        end
      when Array
        value.map { |nested| compact_blank_values(nested) }.compact_blank
      else
        value
      end
    end
  end
end
