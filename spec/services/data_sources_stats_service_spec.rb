# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DataSourcesStatsService do
  let(:user) { create(:user) }

  let(:now) { Time.zone.local(2024, 1, 15, 0, 0, 0) }
  let(:last_week) { now - 1.week }
  let(:last_month) { now - 1.month }

  let(:workspace) { create(:workspace_with_owner, owner: user) }

  let!(:data_source_1) { create(:data_source, workspace:) }
  let!(:data_source_2) { create(:data_source, workspace:) }
  let!(:data_source_3) { create(:data_source, workspace:) }

  before do
    create(:click, data_source_uuid: data_source_1.external_uuid, timestamp: now)
    create(:page_view, data_source_uuid: data_source_1.external_uuid, timestamp: now)

    create(:click, data_source_uuid: data_source_2.external_uuid, timestamp: now)
    create(:page_view, data_source_uuid: data_source_2.external_uuid, timestamp: last_month)
    create(:page_view, data_source_uuid: data_source_2.external_uuid, timestamp: last_month)
    create(:session, data_source_uuid: data_source_2.external_uuid, timestamp: last_month)

    create(:query, data_source: data_source_1, saved: true)
    create(:query, data_source: data_source_1, saved: true)
    create(:query, data_source: data_source_1, saved: true)

    create(:query, data_source: data_source_2, saved: true)
    create(:query, data_source: data_source_2, saved: true)

    allow(Time).to receive(:current).and_return(now)
  end

  let(:instance) { DataSourcesStatsService.new(data_sources: [data_source_1, data_source_2, data_source_3]) }

  describe '#total_events_for' do
    it 'returns the correct counts' do
      expect(instance.total_events_for(data_source: data_source_1)).to eq(2)
      expect(instance.total_events_for(data_source: data_source_2)).to eq(4)
      expect(instance.total_events_for(data_source: data_source_3)).to eq(0)
    end
  end

  describe '#monthly_events_for' do
    it 'returns the correct counts' do
      expect(instance.monthly_events_for(data_source: data_source_1)).to eq(2)
      expect(instance.monthly_events_for(data_source: data_source_2)).to eq(1)
      expect(instance.monthly_events_for(data_source: data_source_3)).to eq(0)
    end
  end

  describe '#monthly_events_limit_for' do
    it 'returns an even share for all data sources' do
      expect(instance.monthly_events_limit_for(data_source: data_source_1)).to eq(5000)
      expect(instance.monthly_events_limit_for(data_source: data_source_2)).to eq(5000)
      expect(instance.monthly_events_limit_for(data_source: data_source_3)).to eq(5000)
    end
  end

  describe '#queries_for' do
    it 'returns the correct counts' do
      expect(instance.queries_for(data_source: data_source_1)).to eq(3)
      expect(instance.queries_for(data_source: data_source_2)).to eq(2)
      expect(instance.queries_for(data_source: data_source_3)).to eq(0)
    end
  end
end
