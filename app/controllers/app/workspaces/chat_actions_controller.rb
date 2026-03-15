# frozen_string_literal: true

module App
  module Workspaces
    class ChatActionsController < ApplicationController # rubocop:disable Metrics/ClassLength
      before_action :require_authentication!

      # rubocop:disable Metrics/AbcSize
      def confirm
        validation_error = confirmation_validation_error
        return render_action_error(status: :unprocessable_entity, message: validation_error) if validation_error

        execution = Chat::ActionExecutor.new(workspace:, actor: current_user).execute(
          action_type: action_request.action_type,
          payload: action_request.payload
        )
        assistant_content = chat_response_composer.compose(
          execution:,
          action_type: action_request.action_type
        )

        action_request.update!(
          status: status_for_result(result_status: execution.status),
          result_payload: {
            'user_message' => assistant_content,
            'data' => execution.data
          },
          executed_at: Time.current
        )

        append_execution_message(execution:, assistant_content:)
        set_workspace_delete_toast(execution:)

        render json: {
          status: execution.status,
          redirect_path: execution.data[:redirect_path],
          action_request_id: action_request.id
        }
      end
      # rubocop:enable Metrics/AbcSize

      def cancel
        if action_request.pending_confirmation?
          action_request.update!(
            status: ChatActionRequest::Statuses::CANCELED,
            result_payload: { canceled_by: current_user.id }
          )

          chat_thread.chat_messages.create!(
            role: ChatMessage::Roles::ASSISTANT,
            status: ChatMessage::Statuses::COMPLETED,
            content: I18n.t('app.workspaces.chat.messages.action_canceled'),
            metadata: {
              action_request_id: action_request.id,
              action_state: 'canceled'
            }
          )
        end

        render json: {
          status: 'canceled',
          action_request_id: action_request.id
        }
      end

      private

      def workspace
        @workspace ||= find_workspace_for_current_user!(param_key: :workspace_id)
      end

      def chat_thread
        @chat_thread ||= workspace.chat_threads.active.for_user(current_user).find(params[:thread_id])
      end

      def action_request
        @action_request ||= chat_thread.chat_action_requests.find_by!(id: params[:id], requested_by_id: current_user.id)
      end

      def confirmation_validation_error
        unless action_request.pending_confirmation?
          return I18n.t('app.workspaces.chat.errors.action_not_pending_confirmation')
        end
        return I18n.t('app.workspaces.chat.errors.confirmation_expired') if action_request.expired?
        return I18n.t('app.workspaces.chat.errors.invalid_confirmation_token') unless valid_confirmation_token?

        nil
      end

      def valid_confirmation_token?
        submitted_token = params[:confirmation_token].to_s
        stored_token = action_request.confirmation_token.to_s
        return false if submitted_token.blank? || stored_token.blank?
        return false if submitted_token.bytesize != stored_token.bytesize

        ActiveSupport::SecurityUtils.secure_compare(stored_token, submitted_token)
      end

      def append_execution_message(execution:, assistant_content:)
        chat_thread.chat_messages.create!(
          role: ChatMessage::Roles::ASSISTANT,
          status: execution.status == 'executed' ? ChatMessage::Statuses::COMPLETED : ChatMessage::Statuses::FAILED,
          content: assistant_content,
          metadata: {
            action_request_id: action_request.id,
            action_state: execution.status,
            result_data: execution.data,
            action_type: action_request.action_type
          }
        )
      end

      def chat_response_composer
        @chat_response_composer ||= Chat::ResponseComposer.new(
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

      def set_workspace_delete_toast(execution:)
        return unless action_request.action_type == 'workspace.delete'
        return unless execution.status == 'executed'

        # We intentionally persist flash across this JSON response so Turbo.visit can display it on the next page load.
        # rubocop:disable Rails/ActionControllerFlashBeforeRender
        flash[:toast] = delete_workspace_toast(
          failed_notifications: execution.data[:failed_notifications].to_i
        )
        # rubocop:enable Rails/ActionControllerFlashBeforeRender
      end

      def status_for_result(result_status:)
        {
          'executed' => ChatActionRequest::Statuses::EXECUTED,
          'forbidden' => ChatActionRequest::Statuses::FORBIDDEN,
          'validation_error' => ChatActionRequest::Statuses::VALIDATION_ERROR,
          'execution_error' => ChatActionRequest::Statuses::EXECUTION_ERROR
        }.fetch(result_status, ChatActionRequest::Statuses::EXECUTION_ERROR)
      end

      def render_action_error(status:, message:)
        render json: {
          status: 'validation_error',
          error_code: 'validation_error',
          message:
        }, status:
      end

      def delete_workspace_toast(failed_notifications:)
        if failed_notifications.zero?
          return {
            type: 'success',
            title: I18n.t('common.toasts.workspace_successfully_deleted_title'),
            body: I18n.t('toasts.workspaces.deleted.body')
          }
        end

        {
          type: 'information',
          title: I18n.t('common.toasts.workspace_successfully_deleted_title'),
          body: I18n.t('toasts.workspaces.deleted_partial.body')
        }
      end
    end
  end
end
