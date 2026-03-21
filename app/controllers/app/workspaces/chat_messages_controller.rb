# frozen_string_literal: true

module App
  module Workspaces
    class ChatMessagesController < ApplicationController # rubocop:disable Metrics/ClassLength
      before_action :require_authentication!

      def index
        thread = chat_thread
        return render json: { thread_id: nil, messages: [] } unless thread

        render json: {
          thread_id: thread.id,
          messages: serialized_messages_for(thread:)
        }
      end

      # rubocop:disable Metrics/AbcSize
      def create
        validation_error = submission_validation_error
        return render_validation_error(message: validation_error) if validation_error

        user_message = build_user_message
        return render_validation_error(message: user_message.errors.full_messages.to_sentence) unless user_message.save

        assign_thread_title_from_first_message(user_message:)

        outcome = Chat::TurnOrchestrator.new(
          workspace:,
          chat_thread:,
          actor: current_user,
          user_message:,
          content: params[:content],
          tool_metadata: runtime_tool_metadata
        ).call

        set_workspace_delete_toast(outcome:)
        render_turn_outcome(outcome:)
      end
      # rubocop:enable Metrics/AbcSize

      private

      def workspace
        @workspace ||= find_workspace_for_current_user!(param_key: :workspace_id)
      end

      def chat_thread
        @chat_thread ||= if params[:thread_id].present?
                           thread_from_params
                         elsif create_action?
                           create_chat_thread!
                         else
                           default_thread
                         end
      end

      def thread_from_params
        found_thread = user_chat_threads.find_by(id: params[:thread_id])
        return found_thread if found_thread
        return nil unless create_action?

        create_chat_thread!
      end

      def default_thread
        user_chat_threads.with_messages.order(updated_at: :desc, id: :desc).first
      end

      def user_chat_threads
        @user_chat_threads ||= workspace.chat_threads.active.for_user(current_user)
      end

      def create_chat_thread!
        workspace.chat_threads.create!(created_by: current_user)
      end

      def create_action?
        action_name == 'create'
      end

      def should_assign_thread_title?
        chat_thread.title.blank? && chat_thread.chat_messages.where(role: ChatMessage::Roles::USER).count == 1
      end

      def generated_thread_title(user_message:)
        Chat::ThreadTitleService.new(
          message: user_message.content,
          workspace:,
          actor: current_user
        ).call
      end

      def serialized_messages_for(thread:)
        messages = thread.chat_messages.includes(:user, images_attachments: :blob)
        messages = messages.where('chat_messages.id > ?', params[:after_id].to_i) if params[:after_id].present?

        messages.order(:id).map { |message| serialize_message(message:) }
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

      def assign_thread_title_from_first_message(user_message:)
        return unless should_assign_thread_title?

        chat_thread.update!(title: generated_thread_title(user_message:))
      rescue StandardError => e
        Rails.logger.warn("Chat thread title assignment failed: #{e.class} #{e.message}")
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
          content_html: serialized_message_content_html(message:),
          metadata: message.metadata,
          created_at: message.created_at.iso8601,
          author: {
            id: message.user_id,
            name: message.user&.full_name.to_s
          },
          images: message.images.attachments.map { |attachment| serialize_attachment(attachment:) }
        }
      end

      def serialized_message_content_html(message:)
        return unless message.assistant?

        helpers.render_chat_markdown(message.content.to_s)
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

      # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
      def render_turn_outcome(outcome:)
        payload = {
          status: outcome.status,
          thread_id: chat_thread.id,
          messages: outcome.messages.map { |message| serialize_message(message:) },
          data: outcome.data || {}
        }
        payload[:error_code] = outcome.error_code if outcome.error_code.present?
        payload[:redirect_path] = outcome.redirect_path if outcome.redirect_path.present?
        if outcome.action_request
          payload[:action_request] = serialize_action_request(action_request: outcome.action_request)
        end
        if outcome.status == 'canceled' && outcome.action_request
          payload[:action_request_id] = outcome.action_request.id
        end

        render json: payload
      end
      # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity

      def runtime_tool_metadata
        @runtime_tool_metadata ||= Tooling::WorkspaceRegistry.tool_metadata
      end

      def set_workspace_delete_toast(outcome:)
        return unless outcome.action_type == 'workspace.delete'
        return unless outcome.status == 'executed'

        # rubocop:disable Rails/ActionControllerFlashBeforeRender
        flash[:toast] = if outcome.data[:failed_notifications].to_i.zero?
                          {
                            type: 'success',
                            title: I18n.t('common.toasts.workspace_successfully_deleted_title'),
                            body: I18n.t('toasts.workspaces.deleted.body')
                          }
                        else
                          {
                            type: 'information',
                            title: I18n.t('common.toasts.workspace_successfully_deleted_title'),
                            body: I18n.t('toasts.workspaces.deleted_partial.body')
                          }
                        end
        # rubocop:enable Rails/ActionControllerFlashBeforeRender
      end
    end
  end
end
