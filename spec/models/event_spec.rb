# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Event, type: :model do
  describe '::ALL_EVENT_TYPES' do
    it 'returns a list of all the models that are available for querying' do
      expect(Event::ALL_EVENT_TYPES).to match_array([Click, PageView, Session])
    end
  end
end
