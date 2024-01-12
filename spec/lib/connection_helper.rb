# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ConnectionHelper do
  describe '.with_database' do
    it 'connects to the database in the block and resets it after' do
      ConnectionHelper.with_database(:clickhouse) do
        expect(ActiveRecord::Base.retrieve_connection.pool.db_config.name.to_sym).to eq(:clickhouse)
      end

      expect(ActiveRecord::Base.retrieve_connection.pool.db_config.name.to_sym).to eq(:primary)
    end
  end
end
