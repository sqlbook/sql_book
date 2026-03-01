# frozen_string_literal: true

class TranslationKey < ApplicationRecord
  has_many :translation_values, dependent: :destroy

  validates :key, presence: true, uniqueness: true
  validates :content_scope, presence: true
  validate :validate_used_in_entries

  scope :ordered, -> { order(:key) }
  scope :for_area_tag, ->(tag) { where('? = ANY(area_tags)', tag) }
  scope :for_type_tag, ->(tag) { where('? = ANY(type_tags)', tag) }

  private

  def validate_used_in_entries # rubocop:disable Metrics/AbcSize
    Array(used_in).each do |entry|
      label = entry['label'] || entry[:label]
      path = entry['path'] || entry[:path]

      if label.to_s.strip.blank? || path.to_s.strip.blank?
        errors.add(:used_in, 'must include label and path values')
        next
      end

      next if path.to_s.start_with?('/')

      errors.add(:used_in, 'paths must be internal absolute paths starting with "/"')
    end
  end # rubocop:enable Metrics/AbcSize
end
