# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EventRecord, type: :model do
  describe '.all_event_types' do
    it 'returns a list of all the models that are available for querying' do
      expect(EventRecord.all_event_types).to match_array([Click, PageView, Session])
    end
  end
end
