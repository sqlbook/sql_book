# frozen_string_literal: true

# rubocop:disable Style/FormatStringToken
require 'rails_helper'

RSpec.describe Translations::PlaceholderValidator, type: :service do
  describe '.valid_placeholders?' do
    it 'returns true when placeholders are identical' do
      expect(described_class.valid_placeholders?(source: 'Hello %{name}', candidate: 'Hola %{name}')).to be(true)
    end

    it 'returns false when placeholders differ' do
      expect(described_class.valid_placeholders?(source: 'Hello %{name}', candidate: 'Hola')).to be(false)
    end
  end
end
# rubocop:enable Style/FormatStringToken
