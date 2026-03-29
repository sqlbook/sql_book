# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DataSources::Connectors::PostgresConnector do
  describe '#execute_readonly' do
    subject(:execute_readonly) do
      connector.execute_readonly(sql: 'SELECT 1')
    end

    let(:connector) do
      described_class.new(
        connection_attributes: {
          host: 'db.internal',
          port: 5432,
          database_name: 'sqlbook',
          username: 'sqlbook',
          password: 'password'
        }
      )
    end

    before do
      allow(DataSources::QuerySafetyGuard).to receive(:validate!).with(sql: 'SELECT 1')
      allow(DataSources::QuerySafetyGuard).to receive(:limit_sql)
        .with(
          sql: 'SELECT 1',
          max_rows: described_class::DEFAULT_ROW_LIMIT
        )
        .and_return('SELECT 1')
      allow(PG).to receive(:connect).and_raise(PG::ConnectionBad, 'connection failed')
    end

    it 'raises a connection error when the database cannot be reached' do
      expect { execute_readonly }
        .to raise_error(
          DataSources::Connectors::BaseConnector::ConnectionError,
          I18n.t('app.workspaces.data_sources.validation.connection_failed')
        )
    end
  end
end
