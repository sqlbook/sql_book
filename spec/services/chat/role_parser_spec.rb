# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Chat::RoleParser do
  describe '.parse' do
    it 'parses explicit target role updates that include a contrasting old role' do
      parsed = described_class.parse(text: 'Make Tim Bananas a User role instead of Admin please')

      expect(parsed).to eq(Member::Roles::USER)
    end

    it 'parses promote phrasing to admin' do
      parsed = described_class.parse(text: 'Could you promote Tim Bananas to Admin?')

      expect(parsed).to eq(Member::Roles::ADMIN)
    end

    it 'parses read-only role text variants' do
      parsed = described_class.parse(text: 'Set Tim to read only')

      expect(parsed).to eq(Member::Roles::READ_ONLY)
    end
  end
end
