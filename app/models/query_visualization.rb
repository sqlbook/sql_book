# frozen_string_literal: true

class QueryVisualization < ApplicationRecord
  belongs_to :query, inverse_of: :visualizations

  normalizes :chart_type, with: ->(value) { value.to_s.strip.presence }
  normalizes :theme_reference, with: lambda { |value|
    value.to_s.strip.presence || Visualizations::SystemTheme::REFERENCE_KEY
  }

  validates :chart_type, presence: true, inclusion: { in: Visualizations::ChartRegistry.types }
  validates :theme_reference, presence: true
  validates :chart_type, uniqueness: { scope: :query_id }

  before_validation :normalize_json_fields

  def resolved_data_config(query_result: query.query_result)
    defaults = Visualizations::Defaults.data_config(
      chart_type:,
      columns: Array(query_result.columns)
    )

    defaults.deep_merge(data_config)
  end

  def resolved_other_config(query_result: query.query_result)
    defaults = Visualizations::Defaults.other_config(
      chart_type:,
      columns: Array(query_result.columns)
    )

    defaults.deep_merge(other_config)
  end

  def resolved_appearance_config(mode:)
    Visualizations::Defaults.appearance_config.deep_merge(appearance_config_for(mode:))
  end

  def appearance_config_for(mode:)
    case mode.to_s
    when 'light'
      appearance_config_light
    else
      appearance_config_dark
    end
  end

  def selected_theme_entry
    Visualizations::ThemeLibraryService.find_entry(
      workspace: query.data_source.workspace,
      reference: theme_reference
    )
  end

  private

  def normalize_json_fields
    self.data_config = normalized_hash(data_config)
    self.appearance_config_dark = normalized_hash(appearance_config_dark)
    self.appearance_config_light = normalized_hash(appearance_config_light)
    self.other_config = normalized_hash(other_config)
  end

  def normalized_hash(value)
    value.to_h.deep_stringify_keys
  end
end
