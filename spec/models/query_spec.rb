# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Query, type: :model do
  let(:instance) { create(:query) }

  let(:query_service_columns) { [] }
  let(:query_service) { instance_double('QueryService', columns: query_service_columns, clear_cache!: nil) }

  before do
    allow(QueryService).to receive(:new).and_return(query_service)
    allow(query_service).to receive(:execute).and_return(query_service)
  end

  describe '#query_result' do
    subject { instance.query_result }

    it 'returns an instance of the QueryService' do
      expect(subject).to eq(query_service)
    end

    it 'executes the query' do
      subject
      expect(query_service).to have_received(:execute)
    end
  end

  describe '#before_update' do
    context 'when the query has been updated' do
      it 'clears the cache' do
        instance.update(query: 'SELECT * FROM sessions')

        expect(query_service).to have_received(:clear_cache!)
      end
    end

    context 'when the query has not been updated' do
      it 'does not clear the cache' do
        instance.update(name: 'Updated query')

        expect(query_service).not_to have_received(:clear_cache!)
      end
    end
  end

  describe 'chat query reference syncing' do
    let(:workspace) { create(:workspace_with_owner, owner: create(:user)) }
    let(:data_source) { create(:data_source, :postgres, workspace:) }
    let(:instance) do
      create(
        :query,
        data_source:,
        saved: true,
        name: 'User count',
        query: 'SELECT COUNT(*) AS user_count FROM public.users'
      )
    end

    it 'updates linked reference names and preserves aliases when renamed' do
      reference = create(
        :chat_query_reference,
        chat_thread: create(:chat_thread, workspace:, created_by: instance.author),
        data_source:,
        saved_query: instance,
        current_name: 'User count'
      )

      instance.update!(name: 'Database user count')

      expect(reference.reload.current_name).to eq('Database user count')
      expect(reference.name_aliases).to include('User count')
    end

    it 'keeps a thread-only reference when the saved query is deleted' do
      reference = create(
        :chat_query_reference,
        chat_thread: create(:chat_thread, workspace:, created_by: instance.author),
        data_source:,
        saved_query: instance,
        current_name: 'User count'
      )

      instance.destroy!

      expect(reference.reload.saved_query_id).to be_nil
      expect(reference.current_name).to eq('User count')
    end
  end
end
