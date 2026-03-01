# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Translations::UpdateService, type: :service do
  describe '#call' do
    let(:actor) { create(:user) }
    let!(:translation_key) do
      TranslationKey.create!(key: 'sample.update.key', area_tags: ['sample'], type_tags: ['copy'])
    end
    let!(:english_value) { TranslationValue.create!(translation_key:, locale: 'en', value: 'Hello') }

    it 'updates translation metadata and values' do
      rows = {
        translation_key.id.to_s => {
          'id' => translation_key.id,
          'area_tags' => 'sample,admin',
          'type_tags' => 'title,copy',
          'used_in' => "Header | /app/workspaces\nSettings | /app/account-settings",
          'en' => 'Hello',
          'es' => 'Hola'
        }
      }

      result = described_class.new(actor:, rows_params: rows).call

      expect(result).to be(true)
      expect(translation_key.reload.area_tags).to contain_exactly('sample', 'admin')
      expect(translation_key.type_tags).to contain_exactly('title', 'copy')
      expect(translation_key.used_in).to eq(
        [
          { 'label' => 'Header', 'path' => '/app/workspaces' },
          { 'label' => 'Settings', 'path' => '/app/account-settings' }
        ]
      )
      expect(TranslationValue.find_by(translation_key:, locale: 'es')&.value).to eq('Hola')
      expect(TranslationValueRevision.exists?(translation_value: english_value)).to be(false)
      expect(
        TranslationValueRevision.joins(:translation_value).exists?(translation_values: { locale: 'es' })
      ).to be(true)
    end
  end
end
