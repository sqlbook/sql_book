# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Session, type: :model do
  describe '.nice_name' do
    it 'returns a nice name to describe the model' do
      expect(Session.nice_name).to eq('Sessions')
    end
  end
end
