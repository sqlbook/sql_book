# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Visualizations::ThemeResolver do
  describe '.resolve' do
    let(:workspace) { create(:workspace) }

    it 'resolves the built-in system theme and deep merges appearance overrides' do
      payload = described_class.resolve(
        workspace:,
        theme_reference: Visualizations::SystemTheme::REFERENCE_KEY,
        mode: :dark,
        appearance_overrides: {
          'tooltip' => {
            'backgroundColor' => '#101010'
          }
        }
      )

      expect(payload['backgroundColor']).to eq('#1C1C1C')
      expect(payload.dig('tooltip', 'backgroundColor')).to eq('#101010')
      expect(payload.dig('tooltip', 'textStyle', 'color')).to eq('#ECEAE6')
    end

    it 'returns the requested workspace theme variant' do
      theme = create(
        :visualization_theme,
        workspace:,
        theme_json_dark: { 'backgroundColor' => '#111111' },
        theme_json_light: { 'backgroundColor' => '#fefefe' }
      )

      payload = described_class.resolve(
        workspace:,
        theme_reference: theme.reference_key,
        mode: :light
      )

      expect(payload['backgroundColor']).to eq('#fefefe')
    end
  end
end
