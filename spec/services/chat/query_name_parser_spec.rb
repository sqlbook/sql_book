# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Chat::QueryNameParser do
  describe '.parse_proposed_rename_name' do
    it 'returns a concrete proposed rename from assistant copy' do
      result = described_class.parse_proposed_rename_name(
        text: 'I can rename it to Users: names and emails.'
      )

      expect(result).to eq('Users: names and emails')
    end

    it 'ignores vague rename placeholders' do
      result = described_class.parse_proposed_rename_name(
        text: 'If you want, I can also rename it to something shorter or more descriptive.'
      )

      expect(result).to be_nil
    end
  end
end
