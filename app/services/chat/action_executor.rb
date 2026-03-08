# frozen_string_literal: true

module Chat
  class ActionExecutor # rubocop:disable Metrics/ClassLength
    Result = Struct.new(:status, :user_message, :data, :error_code, keyword_init: true)

    RESEND_COOLDOWN = 10.minutes

    def initialize(workspace:, actor:)
      @workspace = workspace
      @actor = actor
    end

    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
    def execute(action_type:, payload:)
      normalized_payload = payload.to_h
      return forbidden_result(reason_code: 'forbidden_scope') if scope_mismatch?(payload: normalized_payload)

      decision = policy.authorize(action_type:, payload: normalized_payload)
      return forbidden_result(reason_code: decision.reason_code) unless decision.allowed

      case action_type
      when 'workspace.update_name' then execute_workspace_update_name(payload: normalized_payload)
      when 'workspace.delete' then execute_workspace_delete
      when 'member.list' then execute_member_list
      when 'member.invite' then execute_member_invite(payload: normalized_payload)
      when 'member.resend_invite' then execute_member_resend(payload: normalized_payload)
      when 'member.update_role' then execute_member_role_update(payload: normalized_payload)
      when 'member.remove' then execute_member_remove(payload: normalized_payload)
      else
        forbidden_result(reason_code: 'forbidden_action')
      end
    rescue ActiveRecord::RecordInvalid => e
      validation_error_result(message: e.record.errors.full_messages.to_sentence)
    rescue StandardError => e
      Rails.logger.error("Chat action failed: #{action_type} #{e.class} #{e.message}")
      execution_error_result(message: I18n.t('app.workspaces.chat.executor.unexpected_error'))
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength

    private

    attr_reader :workspace, :actor

    def policy
      @policy ||= Chat::Policy.new(workspace:, actor:)
    end

    def execute_workspace_update_name(payload:)
      name = payload['name'].to_s.strip
      if name.blank?
        return validation_error_result(message: I18n.t('app.workspaces.chat.executor.workspace_name_required'))
      end

      workspace.update!(name:)
      executed_result(
        message: I18n.t('app.workspaces.chat.executor.workspace_name_updated', name: workspace.name),
        data: { workspace_name: workspace.name }
      )
    end

    def execute_workspace_delete
      result = WorkspaceDeletionService.new(workspace:, deleted_by: actor).call
      unless result.success?
        return execution_error_result(message: I18n.t('app.workspaces.chat.executor.workspace_delete_failed'))
      end

      message = if result.failed_notifications.zero?
                  I18n.t('app.workspaces.chat.executor.workspace_delete_success')
                else
                  I18n.t('app.workspaces.chat.executor.workspace_delete_partial')
                end

      executed_result(
        message:,
        data: { redirect_path: '/app/workspaces', failed_notifications: result.failed_notifications }
      )
    end

    def execute_member_list # rubocop:disable Metrics/AbcSize
      members = workspace.members.includes(:user).map do |member|
        {
          id: member.id,
          name: member.user&.full_name.to_s,
          email: member.user&.email.to_s,
          role: member.role_name,
          role_id: member.role,
          status: member.status_name
        }
      end

      user_message = if members.empty?
                       I18n.t('app.workspaces.chat.executor.member_list_none')
                     else
                       [
                         I18n.t('app.workspaces.chat.executor.member_list_found', count: members.size),
                         members.map { |member| member_list_item_line(member:) }.join("\n")
                       ].join("\n")
                     end

      executed_result(
        message: user_message,
        data: { members: }
      )
    end

    def execute_member_invite(payload:) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      email = payload['email'].to_s.strip.downcase
      if email.blank?
        return validation_error_result(message: I18n.t('app.workspaces.chat.executor.member_invite_email_required'))
      end
      if existing_member?(email:)
        return validation_error_result(message: I18n.t('app.workspaces.chat.executor.member_invite_already_member'))
      end

      first_name = payload['first_name'].to_s.strip
      last_name = payload['last_name'].to_s.strip
      inferred_name_parts = inferred_name_from_email(email:)

      WorkspaceInvitationService.new(workspace:).invite!(
        invited_by: actor,
        first_name: first_name.presence || inferred_name_parts[:first_name],
        last_name: last_name.presence || inferred_name_parts[:last_name],
        email:,
        role: payload['role'].to_i
      )

      executed_result(message: I18n.t('app.workspaces.chat.executor.member_invite_sent', email:))
    end

    def execute_member_resend(payload:) # rubocop:disable Metrics/AbcSize
      member = target_member(payload:)
      return validation_error_result(message: I18n.t('app.workspaces.chat.executor.member_not_found')) unless member
      unless member.pending?
        return validation_error_result(message: I18n.t('app.workspaces.chat.executor.member_resend_only_pending'))
      end

      if member.updated_at > RESEND_COOLDOWN.ago
        return validation_error_result(message: I18n.t('app.workspaces.chat.executor.member_resend_cooldown'))
      end

      WorkspaceInvitationService.new(workspace:).resend!(member:)
      executed_result(message: I18n.t('app.workspaces.chat.executor.member_resend_sent', email: member.user.email))
    end

    def execute_member_role_update(payload:)
      member = target_member(payload:)
      return validation_error_result(message: I18n.t('app.workspaces.chat.executor.member_not_found')) unless member

      role = payload['role'].to_i
      unless Chat::Policy::EDITABLE_ROLES.include?(role)
        return validation_error_result(message: I18n.t('app.workspaces.chat.executor.member_role_invalid'))
      end

      member.update!(role:)
      executed_result(
        message: I18n.t(
          'app.workspaces.chat.executor.member_role_updated',
          name: member.user.full_name,
          role: member.role_name
        )
      )
    end

    def execute_member_remove(payload:) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      member = target_member(payload:)
      return validation_error_result(message: I18n.t('app.workspaces.chat.executor.member_not_found')) unless member
      if member.owner?
        return validation_error_result(message: I18n.t('app.workspaces.chat.executor.member_remove_owner_forbidden'))
      end

      removed_user = member.user
      removed_member_was_accepted = member.status == Member::Status::ACCEPTED
      member.destroy!

      if removed_member_was_accepted
        WorkspaceMailer.workspace_member_removed(user: removed_user, workspace_name: workspace.name).deliver_now
      end

      executed_result(
        message: I18n.t('app.workspaces.chat.executor.member_remove_success', name: removed_user.full_name)
      )
    rescue StandardError => e
      Rails.logger.error(
        "Workspace member removal notification failed for user #{removed_user.id}: #{e.class} #{e.message}"
      )
      executed_result(
        message: I18n.t('app.workspaces.chat.executor.member_remove_success', name: removed_user.full_name)
      )
    end

    def target_member(payload:)
      member_id = payload['member_id'].to_i if payload['member_id'].present?
      return workspace.members.find_by(id: member_id) if member_id

      email = payload['email'].to_s.strip.downcase
      return nil if email.blank?

      workspace.members.joins(:user).find_by(users: { email: })
    end

    def existing_member?(email:)
      workspace.members.joins(:user).exists?(users: { email: })
    end

    def member_list_item_line(member:)
      I18n.t(
        'app.workspaces.chat.executor.member_list_item',
        name: member_field(member[:name], fallback_key: 'member_unknown_name'),
        email: member_field(member[:email], fallback_key: 'member_unknown_email'),
        role: member_field(member[:role], fallback_key: 'member_unknown_role'),
        status: member_field(member[:status], fallback_key: 'member_unknown_status')
      )
    end

    def member_field(value, fallback_key:)
      value.to_s.strip.presence || I18n.t("app.workspaces.chat.executor.#{fallback_key}")
    end

    def inferred_name_from_email(email:)
      base = email.split('@').first.to_s
      segments = base.split(/[._-]/).compact_blank
      {
        first_name: segments.first.to_s.capitalize.presence ||
          I18n.t('app.workspaces.chat.executor.inferred_first_name'),
        last_name: segments.drop(1).join(' ').strip.capitalize.presence ||
          I18n.t('app.workspaces.chat.executor.inferred_last_name')
      }
    end

    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    def scope_mismatch?(payload:)
      payload_workspace_id = payload['workspace_id'].to_i if payload['workspace_id'].present?
      return true if payload_workspace_id && payload_workspace_id != workspace.id

      payload_thread_id = payload['thread_id'].to_i if payload['thread_id'].present?
      return true if payload_thread_id && !workspace.chat_threads.active.exists?(id: payload_thread_id)

      payload_message_id = payload['message_id'].to_i if payload['message_id'].present?
      return false unless payload_message_id

      !workspace.chat_messages.exists?(id: payload_message_id)
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

    def forbidden_result(reason_code:)
      Result.new(
        status: 'forbidden',
        user_message: I18n.t('app.workspaces.chat.executor.forbidden'),
        data: {},
        error_code: reason_code
      )
    end

    def validation_error_result(message:)
      Result.new(
        status: 'validation_error',
        user_message: message,
        data: {},
        error_code: 'validation_error'
      )
    end

    def execution_error_result(message:)
      Result.new(
        status: 'execution_error',
        user_message: message,
        data: {},
        error_code: 'execution_error'
      )
    end

    def executed_result(message:, data: {})
      Result.new(status: 'executed', user_message: message, data:, error_code: nil)
    end
  end
end
