# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  let(:user) { create(:user, first_name: 'John', last_name: 'Densmore') }

  describe '#full_name' do
    it 'returns the full name' do
      expect(user.full_name).to eq('John Densmore')
    end
  end
end
