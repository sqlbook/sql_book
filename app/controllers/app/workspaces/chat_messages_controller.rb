# frozen_string_literal: true

require 'digest'

module App
  module Workspaces
    class ChatMessagesController < ApplicationController # rubocop:disable Metrics/ClassLength
      IDEMPOTENCY_WINDOW = 10.minutes
      CONFIRM_MESSAGE_REGEX = /
        \A\s*(?:i\s+confirm|confirm|yes(?:\s+please)?|go\s+ahead|do\s+it|proceed|continue|si|sí)\b
      /ix
      CANCEL_MESSAGE_REGEX = /\A\s*(?:cancel|stop|never\s+mind|do\s+not|don't|no)\b/i

      before_action :require_authentication!

      def index
        thread = chat_thread
        return render_empty_thread unless thread

        render json: {
          thread_id: thread.id,
          messages: serialized_messages_for(thread:)
        }
      end

      # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
      def create
        validation_error = submission_validation_error
        return render_validation_error(message: validation_error) if validation_error

        user_message = build_user_message
        return render_validation_error(message: user_message.errors.full_messages.to_sentence) unless user_message.save

        assign_thread_title_from_first_message(user_message:)

        pending_action_request = pending_confirmation_action_request
        if pending_action_request
          command_response = render_pending_action_command_response(
            user_message:,
            action_request: pending_action_request
          )
          return command_response if command_response
        end

        action_payload_context = action_payload_context_for(message: user_message)

        runtime = Chat::RuntimeService.new(
          message: params[:content],
          workspace:,
          actor: current_user,
          tool_metadata: runtime_tool_metadata,
          context: {
            attachments: user_message.images.attachments,
            conversation_messages: planner_conversation_messages
          }
        )
        decision = runtime.call

        if decision.missing_information.any?
          follow_up = decision.assistant_message.presence || decision.missing_information.join(' ')
          return render_non_action_response(user_message:, assistant_content: follow_up)
        end

        tool_call = decision.tool_calls.first
        if decision.finalize_without_tools || tool_call.nil?
          assistant_content = decision.assistant_message.presence || I18n.t('app.workspaces.chat.planner.default_help')
          return render_non_action_response(user_message:, assistant_content:)
        end

        tool_definition = runtime_tool_definition(tool_call.tool_name)
        unless tool_definition
          return render_non_action_response(
            user_message:,
            assistant_content: I18n.t('app.workspaces.chat.executor.forbidden')
          )
        end

        payload = tool_call.arguments.to_h.merge(action_payload_context)
        missing_details_message = missing_details_message_for(action_type: tool_call.tool_name, payload:)
        if missing_details_message.present?
          return render_non_action_response(user_message:, assistant_content: missing_details_message)
        end

        preflight_result = action_executor.preflight(action_type: tool_call.tool_name, payload:)
        if preflight_result
          return render_execution_response(
            user_message:,
            execution: preflight_result,
            action_type: tool_call.tool_name
          )
        end

        idempotency_key = nil
        if write_tool?(tool_definition) && idempotency_supported?
          idempotency_key = idempotency_key_for(tool_name: tool_call.tool_name, payload: tool_call.arguments.to_h)
          existing_request = existing_write_request(idempotency_key:)
          if existing_request
            return render_existing_write_response(
              user_message:,
              action_request: existing_request,
              assistant_content: decision.assistant_message
            )
          end
        end

        if confirmation_required?(tool_definition)
          return render_confirmation_response(
            user_message:,
            action_type: tool_call.tool_name,
            payload:,
            assistant_content: decision.assistant_message,
            idempotency_key:
          )
        end

        execution = action_executor.execute(action_type: tool_call.tool_name, payload:)
        if execution.status == 'executed' && read_tool?(tool_definition)
          execution.user_message = runtime.compose_tool_result_message(
            tool_name: tool_call.tool_name,
            tool_arguments: tool_call.arguments.to_h,
            execution:
          )
        end
        assistant_content = compose_execution_message(execution:, action_type: tool_call.tool_name)
        if write_tool?(tool_definition)
          persist_auto_executed_request(
            user_message:,
            action_type: tool_call.tool_name,
            payload:,
            execution_snapshot: {
              result_payload: {
                'user_message' => assistant_content,
                'data' => execution.data
              },
              status: execution.status
            },
            idempotency_key:
          )
        end

        render_execution_response(
          user_message:,
          execution:,
          action_type: tool_call.tool_name,
          assistant_content:
        )
      end
      # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

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

      def action_payload_context_for(message:)
        {
          'workspace_id' => workspace.id,
          'thread_id' => chat_thread.id,
          'message_id' => message.id
        }
      end

      def planner_conversation_messages
        recent_messages = ChatMessage.where(chat_thread:)
          .where(role: [ChatMessage::Roles::USER, ChatMessage::Roles::ASSISTANT])
          .reorder(id: :asc)
          .last(12)

        recent_messages.map do |message|
          role_name = message.role.to_i == ChatMessage::Roles::USER ? 'user' : 'assistant'
          {
            role: role_name,
            content: message.content.to_s,
            metadata: message.metadata
          }
        end
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

      def render_empty_thread
        render json: { thread_id: nil, messages: [] }
      end

      def missing_details_message_for(action_type:, payload:) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
        case action_type
        when 'workspace.update_name'
          return I18n.t('app.workspaces.chat.planner.workspace_rename_needs_name') if payload['name'].to_s.strip.blank?
        when 'member.invite'
          missing_email = payload['email'].to_s.strip.blank?
          missing_name = payload['first_name'].to_s.strip.blank? || payload['last_name'].to_s.strip.blank?
          missing_role = payload['role'].to_s.strip.blank?
          missing_fields = []
          missing_fields << 'email' if missing_email
          missing_fields.push('first_name', 'last_name') if missing_name
          missing_fields << 'role' if missing_role
          prompt_key = Chat::InvitePromptResolver.key_for(missing_fields:)
          return I18n.t(prompt_key) if prompt_key.present?
        when 'member.resend_invite'
          return I18n.t('app.workspaces.chat.planner.member_resend_needs_member') if member_reference_missing?(payload:)
        when 'member.update_role'
          if member_reference_missing?(payload:) && payload['role'].to_s.strip.blank?
            return I18n.t('app.workspaces.chat.planner.member_role_update_needs_member_and_role')
          end
          if member_reference_missing?(payload:)
            return I18n.t('app.workspaces.chat.planner.member_role_update_needs_member')
          end
          if payload['role'].to_s.strip.blank?
            return I18n.t('app.workspaces.chat.planner.member_role_update_needs_role')
          end
        when 'member.remove'
          return I18n.t('app.workspaces.chat.planner.member_remove_needs_member') if member_reference_missing?(payload:)
        end

        nil
      end

      def member_reference_missing?(payload:)
        payload['member_id'].to_s.strip.blank? &&
          payload['email'].to_s.strip.blank? &&
          payload['full_name'].to_s.strip.blank?
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

      def render_confirmation_response(user_message:, action_type:, payload:, assistant_content:, idempotency_key:)
        action_request_attributes = {
          chat_message: user_message,
          requested_by: current_user,
          action_type:,
          payload:,
          status: ChatActionRequest::Statuses::PENDING_CONFIRMATION
        }.merge(idempotency_attributes(idempotency_key:))

        action_request = chat_thread.chat_action_requests.create!(action_request_attributes)
      rescue ActiveRecord::RecordInvalid => e
        raise unless idempotency_collision?(e)

        action_request = recover_confirmation_request!(
          user_message:,
          action_type:,
          payload:,
          idempotency_key:
        )

        render_confirmation_json(
          user_message:,
          action_request:,
          assistant_content:
        )
      else
        render_confirmation_json(
          user_message:,
          action_request:,
          assistant_content:
        )
      end

      def render_confirmation_json(user_message:, action_request:, assistant_content:)
        assistant_message = chat_thread.chat_messages.create!(
          role: ChatMessage::Roles::ASSISTANT,
          status: ChatMessage::Statuses::COMPLETED,
          content: [
            assistant_content.presence || I18n.t('app.workspaces.chat.messages.confirmation_default'),
            I18n.t('app.workspaces.chat.messages.confirm_suffix')
          ].join(' '),
          metadata: {
            action_request_id: action_request.id,
            action_state: 'requires_confirmation'
          }
        )

        render json: {
          status: 'requires_confirmation',
          thread_id: chat_thread.id,
          action_request: serialize_action_request(action_request:),
          messages: [serialize_message(message: user_message), serialize_message(message: assistant_message)]
        }
      end

      def render_execution_response(user_message:, execution:, action_type:, assistant_content: nil)
        assistant_content ||= compose_execution_message(execution:, action_type:)
        assistant_message = chat_thread.chat_messages.create!(
          role: ChatMessage::Roles::ASSISTANT,
          status: execution.status == 'executed' ? ChatMessage::Statuses::COMPLETED : ChatMessage::Statuses::FAILED,
          content: assistant_content,
          metadata: {
            execution_status: execution.status,
            result_data: execution.data,
            action_type:
          }
        )
        render json: {
          status: execution.status,
          thread_id: chat_thread.id,
          messages: [serialize_message(message: user_message), serialize_message(message: assistant_message)],
          data: execution.data
        }
      end

      def render_existing_write_response(user_message:, action_request:, assistant_content:) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        if action_request.pending_confirmation?
          refresh_confirmation_request!(action_request:, user_message:) if action_request.expired?
          pending_content = assistant_content.presence || I18n.t('app.workspaces.chat.messages.request_already_pending')
          assistant_message = chat_thread.chat_messages.create!(
            role: ChatMessage::Roles::ASSISTANT,
            status: ChatMessage::Statuses::COMPLETED,
            content: [pending_content, I18n.t('app.workspaces.chat.messages.confirm_suffix')].join(' '),
            metadata: {
              action_request_id: action_request.id,
              action_state: 'requires_confirmation'
            }
          )
          return render json: {
            status: 'requires_confirmation',
            thread_id: chat_thread.id,
            action_request: serialize_action_request(action_request:),
            messages: [serialize_message(message: user_message), serialize_message(message: assistant_message)]
          }
        end

        duplicated_content = action_request.result_payload.to_h['user_message'].to_s
        if duplicated_content.blank?
          duplicated_content = I18n.t('app.workspaces.chat.messages.request_already_processed')
        end
        assistant_status = if action_request.status == ChatActionRequest::Statuses::EXECUTED
                             ChatMessage::Statuses::COMPLETED
                           else
                             ChatMessage::Statuses::FAILED
                           end
        assistant_message = chat_thread.chat_messages.create!(
          role: ChatMessage::Roles::ASSISTANT,
          status: assistant_status,
          content: duplicated_content
        )

        render json: {
          status: action_request.status_name,
          thread_id: chat_thread.id,
          messages: [serialize_message(message: user_message), serialize_message(message: assistant_message)],
          data: action_request.result_payload.to_h['data'] || {}
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

      def action_executor
        @action_executor ||= Chat::ActionExecutor.new(workspace:, actor: current_user)
      end

      def runtime_tool_metadata
        @runtime_tool_metadata ||= Tooling::WorkspaceTeamRegistry.tool_metadata
      end

      def runtime_tool_definition(tool_name)
        @runtime_tool_definitions ||= runtime_tool_metadata.index_by { |tool| tool[:name] }
        @runtime_tool_definitions[tool_name]
      end

      def write_tool?(tool_definition)
        tool_definition[:risk_level].to_s != 'read'
      end

      def read_tool?(tool_definition)
        tool_definition[:risk_level].to_s == 'read'
      end

      def confirmation_required?(tool_definition)
        tool_definition[:confirmation_mode].to_s == 'required'
      end

      def idempotency_key_for(tool_name:, payload:)
        stable_json = stable_payload_json(payload)
        Digest::SHA256.hexdigest("#{workspace.id}:#{chat_thread.id}:#{current_user.id}:#{tool_name}:#{stable_json}")
      end

      def stable_payload_json(payload)
        JSON.generate(deep_sorted_value(payload))
      end

      def deep_sorted_value(value)
        case value
        when Hash
          value.to_h.sort.to_h { |key, child| [key.to_s, deep_sorted_value(child)] }
        when Array
          value.map { |child| deep_sorted_value(child) }
        else
          value
        end
      end

      def existing_write_request(idempotency_key:)
        return nil unless idempotency_supported?
        return nil if idempotency_key.blank?

        chat_thread.chat_action_requests
          .where(requested_by: current_user, idempotency_key:)
          .where(created_at: IDEMPOTENCY_WINDOW.ago..)
          .order(id: :desc)
          .first
      end

      def conflicting_write_request(idempotency_key:)
        return nil unless idempotency_supported?
        return nil if idempotency_key.blank?

        chat_thread.chat_action_requests
          .where(requested_by: current_user, idempotency_key:)
          .order(id: :desc)
          .first
      end

      def persist_auto_executed_request(
        user_message:,
        action_type:,
        payload:,
        execution_snapshot:,
        idempotency_key:
      )
        attributes = {
          chat_message: user_message,
          requested_by: current_user,
          action_type:,
          payload:,
          result_payload: execution_snapshot[:result_payload],
          status: status_for_result(result_status: execution_snapshot[:status]),
          executed_at: Time.current
        }.merge(idempotency_attributes(idempotency_key:))

        chat_thread.chat_action_requests.create!(attributes)
      rescue ActiveRecord::RecordNotUnique
        nil
      end

      def idempotency_attributes(idempotency_key:)
        return {} unless idempotency_supported?
        return {} if idempotency_key.blank?

        { idempotency_key: }
      end

      def idempotency_supported?
        @idempotency_supported ||= ChatActionRequest.column_names.include?('idempotency_key')
      end

      def status_for_result(result_status:)
        {
          'executed' => ChatActionRequest::Statuses::EXECUTED,
          'forbidden' => ChatActionRequest::Statuses::FORBIDDEN,
          'validation_error' => ChatActionRequest::Statuses::VALIDATION_ERROR,
          'execution_error' => ChatActionRequest::Statuses::EXECUTION_ERROR
        }.fetch(result_status, ChatActionRequest::Statuses::EXECUTION_ERROR)
      end

      def pending_confirmation_action_request
        chat_thread.chat_action_requests
          .pending_confirmation
          .where(requested_by: current_user)
          .order(id: :desc)
          .first
      end

      def recover_confirmation_request!(user_message:, action_type:, payload:, idempotency_key:)
        action_request = conflicting_write_request(idempotency_key:)
        raise ActiveRecord::RecordInvalid, ChatActionRequest.new unless action_request

        action_request.update!(
          chat_message: user_message,
          action_type:,
          payload:,
          status: ChatActionRequest::Statuses::PENDING_CONFIRMATION,
          result_payload: {},
          executed_at: nil,
          confirmation_token: SecureRandom.hex(20),
          confirmation_expires_at: ChatActionRequest::CONFIRMATION_WINDOW.from_now
        )
        action_request
      end

      def refresh_confirmation_request!(action_request:, user_message:)
        action_request.update!(
          chat_message: user_message,
          status: ChatActionRequest::Statuses::PENDING_CONFIRMATION,
          result_payload: {},
          executed_at: nil,
          confirmation_token: SecureRandom.hex(20),
          confirmation_expires_at: ChatActionRequest::CONFIRMATION_WINDOW.from_now
        )
      end

      def idempotency_collision?(error)
        record = error.record
        return false unless record.is_a?(ChatActionRequest)

        record.errors.added?(:idempotency_key, :taken)
      end

      def render_pending_action_command_response(user_message:, action_request:)
        case pending_action_command
        when :confirm
          render_pending_action_confirmation(user_message:, action_request:)
        when :cancel
          render_pending_action_cancellation(user_message:, action_request:)
        end
      end

      def pending_action_command
        content = params[:content].to_s.strip
        return :confirm if content.match?(CONFIRM_MESSAGE_REGEX)
        return :cancel if content.match?(CANCEL_MESSAGE_REGEX)

        nil
      end

      def render_pending_action_confirmation(user_message:, action_request:) # rubocop:disable Metrics/AbcSize
        if action_request.expired?
          return render_non_action_response(
            user_message:,
            assistant_content: I18n.t('app.workspaces.chat.errors.confirmation_expired')
          )
        end

        execution = action_executor.execute(action_type: action_request.action_type, payload: action_request.payload)
        assistant_content = compose_execution_message(execution:, action_type: action_request.action_type)
        action_request.update!(
          status: status_for_result(result_status: execution.status),
          result_payload: {
            'user_message' => assistant_content,
            'data' => execution.data
          },
          executed_at: Time.current
        )
        set_workspace_delete_toast(action_request:, execution:)

        assistant_message = chat_thread.chat_messages.create!(
          role: ChatMessage::Roles::ASSISTANT,
          status: execution.status == 'executed' ? ChatMessage::Statuses::COMPLETED : ChatMessage::Statuses::FAILED,
          content: assistant_content,
          metadata: {
            action_request_id: action_request.id,
            action_state: execution.status,
            confirmed_via_chat: true,
            result_data: execution.data,
            action_type: action_request.action_type
          }
        )

        render json: {
          status: execution.status,
          thread_id: chat_thread.id,
          messages: [serialize_message(message: user_message), serialize_message(message: assistant_message)],
          data: execution.data,
          redirect_path: execution.data[:redirect_path]
        }
      end

      def render_pending_action_cancellation(user_message:, action_request:)
        action_request.update!(
          status: ChatActionRequest::Statuses::CANCELED,
          result_payload: { canceled_by: current_user.id }
        )

        assistant_message = chat_thread.chat_messages.create!(
          role: ChatMessage::Roles::ASSISTANT,
          status: ChatMessage::Statuses::COMPLETED,
          content: I18n.t('app.workspaces.chat.messages.action_canceled'),
          metadata: {
            action_request_id: action_request.id,
            action_state: 'canceled',
            canceled_via_chat: true
          }
        )

        render json: {
          status: 'canceled',
          thread_id: chat_thread.id,
          messages: [serialize_message(message: user_message), serialize_message(message: assistant_message)],
          action_request_id: action_request.id
        }
      end

      def compose_execution_message(execution:, action_type:)
        return execution.user_message if execution.status == 'executed' && action_type == 'member.list'

        chat_response_composer.compose(execution:, action_type:)
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

      def set_workspace_delete_toast(action_request:, execution:)
        return unless action_request.action_type == 'workspace.delete'
        return unless execution.status == 'executed'

        # We intentionally persist flash across this JSON response so Turbo.visit can display it on the next page load.
        # rubocop:disable Rails/ActionControllerFlashBeforeRender
        flash[:toast] = if execution.data[:failed_notifications].to_i.zero?
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
