# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tooling::WorkspaceRegistry do
  describe '.tool_metadata' do
    it 'includes datasource tools alongside workspace team tools' do
      tool_names = described_class.tool_metadata.map { |tool| tool[:name] }

      expect(tool_names).to include(
        'workspace.update_name',
        'member.list',
        'datasource.list',
        'datasource.validate_connection',
        'datasource.create'
      )
    end
  end

  describe '.definitions' do
    it 'combines workspace team and data source tool definitions' do
      handlers = {
        team: instance_double(Tooling::WorkspaceTeamHandlers),
        data_sources: instance_double(Tooling::WorkspaceDataSourceHandlers)
      }

      allow(handlers[:team]).to receive(:workspace_update_name).and_return(Tooling::Result.new(status: 'executed', message: 'ok', data: {}, error_code: nil))
      allow(handlers[:team]).to receive(:workspace_delete).and_return(Tooling::Result.new(status: 'executed', message: 'ok', data: {}, error_code: nil))
      allow(handlers[:team]).to receive(:member_list).and_return(Tooling::Result.new(status: 'executed', message: 'ok', data: {}, error_code: nil))
      allow(handlers[:team]).to receive(:member_invite).and_return(Tooling::Result.new(status: 'executed', message: 'ok', data: {}, error_code: nil))
      allow(handlers[:team]).to receive(:member_resend_invite).and_return(Tooling::Result.new(status: 'executed', message: 'ok', data: {}, error_code: nil))
      allow(handlers[:team]).to receive(:member_update_role).and_return(Tooling::Result.new(status: 'executed', message: 'ok', data: {}, error_code: nil))
      allow(handlers[:team]).to receive(:member_remove).and_return(Tooling::Result.new(status: 'executed', message: 'ok', data: {}, error_code: nil))
      allow(handlers[:data_sources]).to receive(:list).and_return(Tooling::Result.new(status: 'executed', message: 'ok', data: {}, error_code: nil))
      allow(handlers[:data_sources]).to receive(:validate_connection).and_return(Tooling::Result.new(status: 'executed', message: 'ok', data: {}, error_code: nil))
      allow(handlers[:data_sources]).to receive(:create).and_return(Tooling::Result.new(status: 'executed', message: 'ok', data: {}, error_code: nil))

      registry = Tooling::Registry.new(definitions: described_class.definitions(handlers:))
      expect(registry.definition('datasource.list')).to be_present
      expect(registry.definition('datasource.validate_connection')).to be_present
      expect(registry.definition('datasource.create')).to be_present
    end
  end
end
