# frozen_string_literal: true

class VisualizationTheme < ApplicationRecord
  belongs_to :workspace

  normalizes :name, with: ->(value) { value.to_s.strip.presence }

  validates :name, presence: true, uniqueness: { scope: :workspace_id }
  validate :theme_json_shapes

  before_validation :normalize_json_fields
  before_save :unset_other_defaults!, if: :default?

  scope :ordered, -> { order(default: :desc, name: :asc, id: :asc) }

  def reference_key
    "workspace_theme:#{id}"
  end

  def read_only?
    false
  end

  def system_theme?
    false
  end

  private

  def normalize_json_fields
    self.theme_json_dark = normalized_hash(theme_json_dark)
    self.theme_json_light = normalized_hash(theme_json_light)
  end

  def normalized_hash(value)
    value.to_h.deep_stringify_keys
  end

  def theme_json_shapes
    errors.add(:theme_json_dark, :invalid) unless theme_json_dark.is_a?(Hash)
    errors.add(:theme_json_light, :invalid) unless theme_json_light.is_a?(Hash)
  end

  def unset_other_defaults!
    workspace.visualization_themes.where.not(id:).update_all(default: false)
  end
end
