# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Click, type: :model do
  describe '.nice_name' do
    it 'returns a nice name to describe the model' do
      expect(Click.nice_name).to eq('Clicks')
    end
  end
end
