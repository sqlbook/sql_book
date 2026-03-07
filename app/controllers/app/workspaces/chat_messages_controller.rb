# frozen_string_literal: true

module App
  module Workspaces
    class ChatMessagesController < ApplicationController # rubocop:disable Metrics/ClassLength
      before_action :require_authentication!

      def index
        messages = chat_thread.chat_messages.includes(:user, images_attachments: :blob)
        messages = messages.where('chat_messages.id > ?', params[:after_id].to_i) if params[:after_id].present?

        render json: {
          thread_id: chat_thread.id,
          messages: messages.order(:id).map { |message| serialize_message(message:) }
        }
      end

      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      def create
        validation_error = submission_validation_error
        return render_validation_error(message: validation_error) if validation_error

        user_message = build_user_message
        return render_validation_error(message: user_message.errors.full_messages.to_sentence) unless user_message.save

        append_system_message(content: I18n.t('app.workspaces.chat.statuses.thinking'))
        action_payload_context = action_payload_context_for(message: user_message)

        plan = Chat::PlannerService.new(
          message: params[:content],
          workspace:,
          actor: current_user,
          attachments: user_message.images.attachments
        ).call

        if plan.action_type.blank?
          return render_non_action_response(
            user_message:,
            assistant_content: plan.assistant_message
          )
        end

        if Chat::Policy.write_action?(plan.action_type)
          return render_confirmation_response(
            user_message:,
            plan:,
            payload_context: action_payload_context
          )
        end

        append_system_message(content: I18n.t('app.workspaces.chat.statuses.checking_permissions'))
        execution = Chat::ActionExecutor.new(workspace:, actor: current_user).execute(
          action_type: plan.action_type,
          payload: plan.payload.to_h.merge(action_payload_context)
        )

        render_execution_response(user_message:, execution:)
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

      private

      def workspace
        @workspace ||= find_workspace_for_current_user!(param_key: :workspace_id)
      end

      def chat_thread
        @chat_thread ||= if params[:thread_id].present?
                           workspace.chat_threads.active.find_by(id: params[:thread_id]) || default_thread
                         else
                           default_thread
                         end
      end

      def default_thread
        ChatThread.active_for(workspace:, user: current_user)
      end

      def message_blank?
        params[:content].to_s.strip.blank? && images.blank?
      end

      def submission_validation_error
        return I18n.t('app.workspaces.chat.errors.message_or_image_required') if message_blank?
        if images.size > ChatMessage::MAX_IMAGE_COUNT
          return I18n.t('app.workspaces.chat.errors.max_images', count: ChatMessage::MAX_IMAGE_COUNT)
        end
        return I18n.t('app.workspaces.chat.errors.unsupported_images') unless valid_images?
        return I18n.t('app.workspaces.chat.errors.image_too_large') unless image_sizes_valid?

        nil
      end

      def images
        @images ||= Array(params[:images]).compact_blank
      end

      def valid_images?
        images.all? { |image| ChatMessage::ALLOWED_IMAGE_TYPES.include?(image.content_type.to_s) }
      end

      def image_sizes_valid?
        images.all? { |image| image.size <= ChatMessage::MAX_IMAGE_SIZE }
      end

      def build_user_message
        message = chat_thread.chat_messages.new(
          user: current_user,
          role: ChatMessage::Roles::USER,
          status: ChatMessage::Statuses::COMPLETED,
          content: params[:content].to_s.strip.presence
        )

        images.each { |image| message.images.attach(image) }
        message
      end

      def append_system_message(content:)
        chat_thread.chat_messages.create!(
          role: ChatMessage::Roles::SYSTEM,
          status: ChatMessage::Statuses::COMPLETED,
          content:
        )
      end

      def action_payload_context_for(message:)
        {
          'workspace_id' => workspace.id,
          'thread_id' => chat_thread.id,
          'message_id' => message.id
        }
      end

      def render_non_action_response(user_message:, assistant_content:)
        assistant_message = chat_thread.chat_messages.create!(
          role: ChatMessage::Roles::ASSISTANT,
          status: ChatMessage::Statuses::COMPLETED,
          content: assistant_content
        )

        render json: {
          status: 'ok',
          thread_id: chat_thread.id,
          messages: [serialize_message(message: user_message), serialize_message(message: assistant_message)]
        }
      end

      def render_confirmation_response(user_message:, plan:, payload_context:) # rubocop:disable Metrics/AbcSize
        action_request = chat_thread.chat_action_requests.create!(
          chat_message: user_message,
          requested_by: current_user,
          action_type: plan.action_type,
          payload: plan.payload.to_h.merge(payload_context),
          status: ChatActionRequest::Statuses::PENDING_CONFIRMATION
        )

        assistant_message = chat_thread.chat_messages.create!(
          role: ChatMessage::Roles::ASSISTANT,
          status: ChatMessage::Statuses::COMPLETED,
          content: [
            plan.assistant_message,
            I18n.t('app.workspaces.chat.messages.confirm_suffix')
          ].join(' '),
          metadata: {
            action_request_id: action_request.id,
            action_state: 'requires_confirmation'
          }
        )

        append_system_message(content: I18n.t('app.workspaces.chat.statuses.ready_to_confirm'))

        render json: {
          status: 'requires_confirmation',
          thread_id: chat_thread.id,
          action_request: serialize_action_request(action_request:),
          messages: [serialize_message(message: user_message), serialize_message(message: assistant_message)]
        }
      end

      def render_execution_response(user_message:, execution:)
        assistant_message = chat_thread.chat_messages.create!(
          role: ChatMessage::Roles::ASSISTANT,
          status: execution.status == 'executed' ? ChatMessage::Statuses::COMPLETED : ChatMessage::Statuses::FAILED,
          content: execution.user_message,
          metadata: {
            execution_status: execution.status,
            result_data: execution.data
          }
        )
        append_system_message(content: I18n.t('app.workspaces.chat.statuses.done'))

        render json: {
          status: execution.status,
          thread_id: chat_thread.id,
          messages: [serialize_message(message: user_message), serialize_message(message: assistant_message)],
          data: execution.data
        }
      end

      def render_validation_error(message:)
        render json: {
          status: 'validation_error',
          error_code: 'validation_error',
          message:
        }, status: :unprocessable_entity
      end

      def serialize_message(message:) # rubocop:disable Metrics/AbcSize
        {
          id: message.id,
          thread_id: message.chat_thread_id,
          role: message.role_name,
          status: message.status_name,
          content: message.content.to_s,
          metadata: message.metadata,
          created_at: message.created_at.iso8601,
          author: {
            id: message.user_id,
            name: message.user&.full_name.to_s
          },
          images: message.images.attachments.map { |attachment| serialize_attachment(attachment:) }
        }
      end

      def serialize_attachment(attachment:)
        {
          id: attachment.id,
          filename: attachment.blob.filename.to_s,
          content_type: attachment.blob.content_type.to_s,
          byte_size: attachment.blob.byte_size,
          url: Rails.application.routes.url_helpers.rails_blob_path(attachment.blob, only_path: true)
        }
      end

      def serialize_action_request(action_request:)
        {
          id: action_request.id,
          action_type: action_request.action_type,
          status: action_request.status_name,
          payload: action_request.payload,
          confirmation_token: action_request.confirmation_token,
          confirmation_expires_at: action_request.confirmation_expires_at&.iso8601
        }
      end
    end
  end
end
