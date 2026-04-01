# frozen_string_literal: true

module App
  module Workspaces
    class ChatQueryCardsController < ApplicationController # rubocop:disable Metrics/ClassLength
      before_action :require_authentication!

      def save
        process_query_card_action(action_type: 'query.save', payload: query_save_payload)
      end

      def save_as_new
        process_query_card_action(action_type: 'query.save', payload: query_save_payload)
      end

      def save_changes
        process_query_card_action(action_type: 'query.update', payload: query_update_payload)
      end

      private

      def workspace
        @workspace ||= find_workspace_for_current_user!(param_key: :workspace_id)
      end

      def chat_thread
        @chat_thread ||= workspace.chat_threads.active.for_user(current_user).find(params[:thread_id])
      end

      def source_message
        @source_message ||= chat_thread.chat_messages.find_by!(
          id: params[:message_id],
          role: ChatMessage::Roles::ASSISTANT
        )
      end

      def query_card
        @query_card ||= source_message.metadata.to_h.deep_stringify_keys['query_card'].to_h.deep_stringify_keys
      end

      def query_save_payload
        {
          'sql' => query_card['sql'],
          'question' => query_card['question'],
          'name' => query_card['suggested_name'],
          'data_source_id' => query_card.dig('data_source', 'id')
        }.compact
      end

      def query_update_payload
        {
          'query_id' => query_card.dig('base_saved_query', 'id'),
          'sql' => query_card['sql']
        }.compact
      end

      def process_query_card_action(action_type:, payload:)
        return render_action_error(message: I18n.t('app.workspaces.chat.query_card.invalid_state')) if query_card.blank?

        execution = execute_query_card_action(action_type:, payload:)
        assistant_content = response_composer.compose(execution:, action_type:)
        assistant_message = create_assistant_message(execution:, assistant_content:, action_type:)

        persist_query_artifacts_for(action_type:, execution:, assistant_message:)
        render json: query_card_action_response(assistant_message:, execution:)
      end

      def generated_name_conflict?(action_type:, execution:)
        action_type == 'query.save' &&
          execution.status == 'validation_error' &&
          execution.error_code == 'generated_name_conflict'
      end

      def execute_query_card_action(action_type:, payload:)
        execution = action_executor.execute(action_type:, payload:)
        execution = execution_truth_reconciler.call(action_type:, payload:, execution:)
        persist_query_save_name_conflict_for(execution:) if generated_name_conflict?(action_type:, execution:)
        execution
      end

      def persist_query_save_name_conflict_for(execution:)
        pending_follow_up_manager.replace!(
          kind: 'query_save_name_conflict',
          domain: 'query',
          source_message: source_message,
          payload: query_save_name_conflict_payload(execution:)
        )
      end

      def query_save_name_conflict_payload(execution:)
        data = execution.data.to_h.deep_stringify_keys

        {
          'sql' => query_card['sql'],
          'question' => query_card['question'],
          'data_source_id' => query_card.dig('data_source', 'id'),
          'data_source_name' => query_card.dig('data_source', 'name'),
          'proposed_name' => data['proposed_name'],
          'conflicting_query_id' => data.dig('conflicting_query', 'id'),
          'conflicting_query_name' => data.dig('conflicting_query', 'name')
        }
      end

      def update_source_message_query_card!(action_type:, execution:)
        return unless execution.status == 'executed'

        updated_card = updated_query_card_for(action_type:, execution:)
        return if updated_card.blank?

        metadata = source_message.metadata.to_h.deep_stringify_keys
        metadata['query_card'] = updated_card
        source_message.update!(metadata:)
      end

      def updated_query_card_for(action_type:, execution:)
        query_payload = execution.data.to_h.deep_stringify_keys['query'].to_h.deep_stringify_keys
        return {} if query_payload.blank?

        updated_card = query_card.deep_dup
        updated_card['state'] = 'saved'
        updated_card['saved_query'] = serialized_query_payload(query_payload)
        updated_card.delete('base_saved_query') if action_type == 'query.update'
        updated_card
      end

      def serialized_query_payload(query_payload)
        data_source = query_payload['data_source'].to_h.deep_stringify_keys

        {
          'id' => query_payload['id'],
          'name' => query_payload['name'],
          'data_source_id' => data_source['id'],
          'data_source_name' => data_source['name'],
          'sql' => query_payload['sql']
        }.compact
      end

      def persist_query_artifacts_for(action_type:, execution:, assistant_message:)
        persist_recent_query_state_for(execution:)
        persist_query_reference_for(action_type:, execution:, assistant_message:)
        update_source_message_query_card!(action_type:, execution:)
      end

      def query_card_action_response(assistant_message:, execution:)
        {
          status: execution.status,
          thread_id: chat_thread.id,
          updated_message: serialize_message(message: source_message.reload),
          messages: [serialize_message(message: assistant_message)]
        }
      end

      def create_assistant_message(execution:, assistant_content:, action_type:)
        chat_thread.chat_messages.create!(
          role: ChatMessage::Roles::ASSISTANT,
          status: execution.status == 'executed' ? ChatMessage::Statuses::COMPLETED : ChatMessage::Statuses::FAILED,
          content: assistant_content.to_s.strip,
          metadata: {
            action_state: execution.status,
            result_data: execution.data,
            action_type:
          }
        )
      end

      def serialize_message(message:)
        {
          id: message.id,
          thread_id: message.chat_thread_id,
          role: message.role_name,
          status: message.status_name,
          content: message.content.to_s,
          content_html: helpers.render_chat_message_body(message:),
          metadata: message.metadata,
          created_at: message.created_at.iso8601,
          author: {
            id: message.user_id,
            name: message.user&.full_name.to_s
          },
          images: []
        }
      end

      def persist_recent_query_state_for(execution:)
        query_payload = execution.data.to_h.deep_stringify_keys['query'].to_h.deep_stringify_keys
        return if query_payload.blank?

        recent_query_state_store.save(
          base_recent_query_state.merge(
            'saved_query_id' => query_payload['id'],
            'saved_query_name' => query_payload['name']
          )
        )
      end

      def persist_query_reference_for(action_type:, execution:, assistant_message:)
        return unless execution.status == 'executed'

        case action_type
        when 'query.save'
          query_reference_store.record_query_save!(
            source_message:,
            result_message: assistant_message,
            execution:,
            fallback_question: query_card['question']
          )
        when 'query.update'
          query_reference_store.record_query_update!(
            source_message:,
            result_message: assistant_message,
            execution:,
            fallback_question: query_card['question']
          )
        end
      end

      def action_executor
        @action_executor ||= Chat::ActionExecutor.new(workspace:, actor: current_user)
      end

      def execution_truth_reconciler
        @execution_truth_reconciler ||= Chat::ExecutionTruthReconciler.new(workspace:)
      end

      def response_composer
        @response_composer ||= Chat::ResponseComposer.new(
          workspace:,
          actor: current_user,
          prior_assistant_messages: prior_assistant_messages
        )
      end

      def prior_assistant_messages
        @prior_assistant_messages ||= chat_thread.chat_messages
          .where(role: ChatMessage::Roles::ASSISTANT)
          .order(id: :desc)
          .limit(3)
      end

      def recent_query_state_store
        @recent_query_state_store ||= Chat::RecentQueryStateStore.new(
          workspace:,
          actor: current_user,
          chat_thread:
        )
      end

      def query_reference_store
        @query_reference_store ||= Chat::QueryReferenceStore.new(
          workspace:,
          actor: current_user,
          chat_thread:
        )
      end

      def pending_follow_up_manager
        @pending_follow_up_manager ||= Chat::PendingFollowUpManager.new(
          workspace:,
          actor: current_user,
          chat_thread:
        )
      end

      def render_action_error(message:)
        render json: {
          status: 'validation_error',
          error_code: 'validation_error',
          message:
        }, status: :unprocessable_entity
      end

      def base_recent_query_state
        {
          'question' => query_card['question'],
          'sql' => query_card['sql'],
          'data_source_id' => query_card.dig('data_source', 'id'),
          'data_source_name' => query_card.dig('data_source', 'name'),
          'row_count' => query_card['row_count'],
          'columns' => query_card['columns']
        }
      end
    end
  end
end
