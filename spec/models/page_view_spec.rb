# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PageView, type: :model do
  describe '.nice_name' do
    it 'returns a nice name to describe the model' do
      expect(PageView.nice_name).to eq('Page Views')
    end
  end
end
