# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Translations::RuntimeLookupService, type: :service do
  describe '.fetch' do
    let!(:translation_key) do
      TranslationKey.create!(key: 'sample.lookup.key', area_tags: ['sample'], type_tags: ['copy'])
    end

    before do
      TranslationValue.create!(translation_key:, locale: 'en', value: 'Hello')
      TranslationValue.create!(translation_key:, locale: 'es', value: 'Hola')
      described_class.bump_version!
    end

    it 'returns locale specific value when present' do
      expect(described_class.fetch(locale: 'es', key: translation_key.key)).to eq('Hola')
    end

    it 'falls back to english when locale value is missing' do
      TranslationValue.find_by(translation_key:, locale: 'es').destroy!
      described_class.bump_version!

      expect(described_class.fetch(locale: 'es', key: translation_key.key)).to eq('Hello')
    end

    it 'returns nil when no value exists' do
      expect(described_class.fetch(locale: 'en', key: 'unknown.key')).to be_nil
    end

    it 'reuses a duplicate english translation when locale value is missing' do
      TranslationValue.find_by(translation_key:, locale: 'es').destroy!

      duplicate_key = TranslationKey.create!(
        key: 'sample.lookup.duplicate',
        area_tags: ['sample'],
        type_tags: ['copy']
      )
      TranslationValue.create!(translation_key: duplicate_key, locale: 'en', value: 'Hello')
      TranslationValue.create!(translation_key: duplicate_key, locale: 'es', value: 'Hola compartido')
      described_class.bump_version!

      expect(described_class.fetch(locale: 'es', key: translation_key.key)).to eq('Hola compartido')
    end
  end
end
