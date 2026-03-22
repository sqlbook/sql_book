# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Chat::QueryReferenceStore, type: :service do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace_with_owner, owner: user) }
  let(:chat_thread) { create(:chat_thread, workspace:, created_by: user) }
  let(:data_source) { create(:data_source, :postgres, workspace:, name: 'Staging App DB') }
  let(:store) { described_class.new(chat_thread:, workspace:, actor: user) }

  describe '#load' do
    it 'seeds a first reference from legacy recent_query_state when needed' do
      Chat::RecentQueryStateStore.new(workspace:, actor: user, chat_thread:).save(
        'question' => 'How many users do I have?',
        'sql' => 'SELECT COUNT(*) AS user_count FROM public.users',
        'data_source_id' => data_source.id,
        'data_source_name' => data_source.display_name,
        'row_count' => 1,
        'columns' => ['user_count']
      )

      expect { store.load }
        .to change(ChatQueryReference, :count).by(1)

      reference = chat_thread.chat_query_references.first
      expect(reference.original_question).to eq('How many users do I have?')
      expect(reference.sql).to eq('SELECT COUNT(*) AS user_count FROM public.users')
      expect(reference.current_name).to eq('User count')
    end
  end

  describe '#record_query_save!' do
    it 'attaches the saved query to the matching unsaved thread reference' do
      source_message = create(:chat_message, chat_thread:, user:, content: 'How many users do I have?')
      result_message = create(
        :chat_message,
        chat_thread:,
        role: ChatMessage::Roles::ASSISTANT,
        status: ChatMessage::Statuses::COMPLETED,
        content: 'Found 3 users.'
      )
      reference = create(
        :chat_query_reference,
        chat_thread:,
        source_message:,
        result_message:,
        data_source:,
        saved_query: nil,
        original_question: 'How many users do I have?',
        sql: 'SELECT COUNT(*) AS user_count FROM public.users',
        current_name: 'User count'
      )
      saved_query = create(
        :query,
        data_source:,
        saved: true,
        name: 'User count',
        query: 'SELECT COUNT(*) AS user_count FROM public.users',
        author: user,
        last_updated_by: user
      )
      execution = Struct.new(:data).new(
        {
          'query' => {
            'id' => saved_query.id,
            'name' => saved_query.name
          }
        }
      )

      expect do
        store.record_query_save!(
          source_message:,
          result_message: create(
            :chat_message,
            chat_thread:,
            role: ChatMessage::Roles::ASSISTANT,
            content: 'Saved it.'
          ),
          execution:,
          fallback_question: 'How many users do I have?'
        )
      end.not_to change(ChatQueryReference, :count)

      expect(reference.reload.saved_query_id).to eq(saved_query.id)
      expect(reference.current_name).to eq('User count')
    end
  end

  describe '#record_query_run!' do
    it 'links a refinement draft back to the recent saved query reference' do
      saved_query = create(
        :query,
        data_source:,
        saved: true,
        name: 'User count',
        query: 'SELECT COUNT(*) AS user_count FROM public.users',
        author: user,
        last_updated_by: user
      )
      saved_reference = create(
        :chat_query_reference,
        chat_thread:,
        data_source:,
        saved_query: saved_query,
        sql: saved_query.query,
        current_name: saved_query.name
      )

      execution = Struct.new(:data).new(
        {
          'question' => 'Adjust the query so it only counts super admins',
          'sql' => 'SELECT COUNT(*) AS user_count FROM public.users WHERE super_admin = true',
          'data_source' => { 'id' => data_source.id, 'name' => data_source.display_name },
          'row_count' => 1,
          'columns' => ['user_count']
        }
      )

      store.record_query_run!(
        source_message: create(:chat_message, chat_thread:, user:, content: 'Adjust it'),
        result_message: create(:chat_message, chat_thread:, role: ChatMessage::Roles::ASSISTANT, content: 'Adjusted.'),
        execution:,
        fallback_question: 'Adjust the query so it only counts super admins'
      )

      draft_reference = chat_thread.chat_query_references.recent_first.first
      expect(draft_reference.refined_from_reference_id).to eq(saved_reference.id)
    end
  end

  describe '#record_query_update!' do
    it 'keeps the existing saved query reference in sync after an update' do
      saved_query = create(
        :query,
        data_source:,
        saved: true,
        name: 'User count',
        query: 'SELECT COUNT(*) AS user_count FROM public.users',
        author: user,
        last_updated_by: user
      )
      reference = create(
        :chat_query_reference,
        chat_thread:,
        data_source:,
        saved_query: saved_query,
        sql: saved_query.query,
        current_name: saved_query.name
      )

      saved_query.update!(
        name: 'User count by super admin status',
        query: <<~SQL.squish
          SELECT super_admin, COUNT(*) AS user_count
          FROM public.users
          GROUP BY super_admin
          ORDER BY super_admin
        SQL
      )
      execution = Struct.new(:data).new(
        {
          'query' => {
            'id' => saved_query.id,
            'name' => saved_query.name
          }
        }
      )

      store.record_query_update!(
        source_message: create(:chat_message, chat_thread:, user:, content: 'Update it'),
        result_message: create(:chat_message, chat_thread:, role: ChatMessage::Roles::ASSISTANT, content: 'Updated.'),
        execution:,
        fallback_question: 'Update the query'
      )

      expect(reference.reload.current_name).to eq('User count by super admin status')
      expect(reference.sql).to include('GROUP BY super_admin')
      expect(reference.name_aliases).to include('User count')
    end
  end

  describe '#record_query_delete!' do
    it 'keeps a thread-only reference after a saved query is deleted' do
      saved_query = create(
        :query,
        data_source:,
        saved: true,
        name: 'User count',
        query: 'SELECT COUNT(*) AS user_count FROM public.users',
        author: user,
        last_updated_by: user
      )
      reference = create(
        :chat_query_reference,
        chat_thread:,
        data_source:,
        saved_query: saved_query,
        original_question: 'How many users do I have?',
        sql: saved_query.query,
        current_name: saved_query.name
      )
      saved_query.destroy!
      execution = Struct.new(:data).new(
        {
          'deleted_query' => {
            'id' => reference.id,
            'name' => 'User count',
            'sql' => 'SELECT COUNT(*) AS user_count FROM public.users',
            'data_source' => {
              'id' => data_source.id,
              'name' => data_source.display_name
            }
          }
        }
      )

      expect do
        store.record_query_delete!(
          result_message: create(
            :chat_message,
            chat_thread:,
            role: ChatMessage::Roles::ASSISTANT,
            content: 'Deleted it.'
          ),
          execution:
        )
      end.not_to change(ChatQueryReference, :count)

      expect(reference.reload.saved_query_id).to be_nil
      expect(reference.current_name).to eq('User count')
      expect(reference.sql).to eq('SELECT COUNT(*) AS user_count FROM public.users')
    end
  end
end
