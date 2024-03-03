# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WorkspacesStatsService do
  let(:user) { create(:user) }

  let(:now) { Time.zone.local(2024, 1, 15, 0, 0, 0) }
  let(:last_week) { now - 1.week }
  let(:last_month) { now - 1.month }

  let(:workspace_1) { create(:workspace_with_owner, owner: user) }
  let(:workspace_2) { create(:workspace_with_owner, owner: user) }

  let!(:data_source_1) { create(:data_source, workspace: workspace_1) }
  let!(:data_source_2) { create(:data_source, workspace: workspace_1) }
  let!(:data_source_3) { create(:data_source, workspace: workspace_2) }

  before do
    create(:click, data_source_uuid: data_source_1.external_uuid, timestamp: now)
    create(:page_view, data_source_uuid: data_source_1.external_uuid, timestamp: now)

    create(:click, data_source_uuid: data_source_2.external_uuid, timestamp: now)
    create(:page_view, data_source_uuid: data_source_2.external_uuid, timestamp: last_month)
    create(:page_view, data_source_uuid: data_source_2.external_uuid, timestamp: last_month)
    create(:session, data_source_uuid: data_source_2.external_uuid, timestamp: last_month)

    allow(Time).to receive(:current).and_return(now)
  end

  let(:instance) { WorkspacesStatsService.new(workspaces: [workspace_1, workspace_2]) }

  describe '#monthly_events_for' do
    it 'returns the sum of the events for each workspace' do
      expect(instance.monthly_events_for(workspace: workspace_1)).to eq(3)
      expect(instance.monthly_events_for(workspace: workspace_2)).to eq(0)
    end
  end

  describe '#monthly_events_limit_for' do
    it 'returns the event limit for the workspaces' do
      expect(instance.monthly_events_limit_for(workspace: workspace_1)).to eq(workspace_1.event_limit)
      expect(instance.monthly_events_limit_for(workspace: workspace_2)).to eq(workspace_2.event_limit)
    end
  end
end
