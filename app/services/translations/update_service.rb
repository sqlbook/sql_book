# frozen_string_literal: true

module Translations
  class UpdateService
    PERMITTED_LOCALES = %w[en es].freeze

    def initialize(actor:, rows_params:)
      @actor = actor
      @rows_params = rows_params
    end

    def call
      ActiveRecord::Base.transaction do
        rows_params.each_value do |row|
          update_row!(row:)
        end
      end

      RuntimeLookupService.bump_version!
      true
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound
      false
    end

    private

    attr_reader :actor, :rows_params

    def update_row!(row:)
      translation_key = TranslationKey.find(row.fetch('id'))
      update_metadata!(translation_key:, row:)
      update_locales!(translation_key:, row:)
    end

    def update_metadata!(translation_key:, row:)
      metadata_updates = {}
      metadata_updates[:area_tags] = normalize_tags(row['area_tags']) if row.key?('area_tags')
      metadata_updates[:type_tags] = normalize_tags(row['type_tags']) if row.key?('type_tags')
      translation_key.update!(metadata_updates) if metadata_updates.any?
    end

    def update_locales!(translation_key:, row:)
      PERMITTED_LOCALES.each do |locale|
        upsert_value!(translation_key:, locale:, value: row[locale].to_s) if row.key?(locale)
      end
    end

    def upsert_value!(translation_key:, locale:, value:)
      translation_value = TranslationValue.find_or_initialize_by(translation_key:, locale:)
      previous_value = translation_value.value.to_s
      return if translation_value.persisted? && previous_value == value

      source = translation_value.persisted? ? 'manual' : 'seed'
      translation_value.update!(value:, source:, updated_by: actor)
      create_revision!(translation_value:, locale:, old_value: previous_value, new_value: value, change_source: source)
    end

    def create_revision!(translation_value:, locale:, old_value:, new_value:, change_source:)
      TranslationValueRevision.create!(
        translation_value:,
        locale:,
        old_value: old_value.presence,
        new_value:,
        changed_by: actor,
        change_source:
      )
    end

    def normalize_tags(raw_value)
      raw_value.to_s
        .split(',')
        .map(&:strip)
        .compact_blank
        .uniq
    end
  end
end
