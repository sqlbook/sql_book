# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Visualizations::ThemeTokens do
  describe '.resolve' do
    it 'resolves the system theme tokens for dark mode' do
      payload = described_class.resolve(described_class.default_theme, mode: :dark)

      expect(payload['backgroundColor']).to eq('#1C1C1C')
      expect(payload['textStyle']['color']).to eq('#ECEAE6')
      expect(payload['color']).to include('#F5807B', '#5CA1F2')
    end

    it 'resolves the system theme tokens for light mode' do
      payload = described_class.resolve(described_class.default_theme, mode: :light)

      expect(payload['backgroundColor']).to eq('#F4F2EE')
      expect(payload['textStyle']['color']).to eq('#111111')
      expect(payload['color']).to include('#FF6A64', '#3E86D9')
    end
  end
end
