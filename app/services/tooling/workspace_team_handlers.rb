# frozen_string_literal: true

module Tooling
  class WorkspaceTeamHandlers # rubocop:disable Metrics/ClassLength
    RESEND_COOLDOWN = 10.minutes

    def initialize(workspace:, actor:)
      @workspace = workspace
      @actor = actor
    end

    def workspace_update_name(arguments:)
      name = arguments['name'].to_s.strip
      return validation_error(message: I18n.t('app.workspaces.chat.executor.workspace_name_required')) if name.blank?

      workspace.update!(name:)
      executed(
        message: I18n.t('app.workspaces.chat.executor.workspace_name_updated', name: workspace.name),
        data: { workspace_name: workspace.name }
      )
    end

    def workspace_delete(*)
      result = WorkspaceDeletionService.new(workspace:, deleted_by: actor).call
      unless result.success?
        return execution_error(message: I18n.t('app.workspaces.chat.executor.workspace_delete_failed'))
      end

      message = if result.failed_notifications.zero?
                  I18n.t('app.workspaces.chat.executor.workspace_delete_success')
                else
                  I18n.t('app.workspaces.chat.executor.workspace_delete_partial')
                end

      executed(
        message:,
        data: { redirect_path: '/app/workspaces', failed_notifications: result.failed_notifications }
      )
    end

    def member_list(*) # rubocop:disable Metrics/AbcSize
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

      executed(message: user_message, data: { members: })
    end

    def member_invite(arguments:) # rubocop:disable Metrics/AbcSize
      email = arguments['email'].to_s.strip.downcase
      first_name = arguments['first_name'].to_s.strip
      last_name = arguments['last_name'].to_s.strip
      role = normalized_invite_role(arguments['role'])
      error_message = invite_validation_error_message(
        first_name:,
        last_name:,
        email:,
        role:,
        raw_role: arguments['role']
      )
      return validation_error(message: error_message) if error_message

      role ||= Member::Roles::USER

      WorkspaceInvitationService.new(workspace:).invite!(
        invited_by: actor,
        first_name:,
        last_name:,
        email:,
        role:
      )

      executed(message: I18n.t('app.workspaces.chat.executor.member_invite_sent', email:))
    end

    def member_resend_invite(arguments:) # rubocop:disable Metrics/AbcSize
      member = target_member(arguments:)
      return validation_error(message: I18n.t('app.workspaces.chat.executor.member_not_found')) unless member
      unless member.pending?
        return validation_error(message: I18n.t('app.workspaces.chat.executor.member_resend_only_pending'))
      end
      if member.updated_at > RESEND_COOLDOWN.ago
        return validation_error(message: I18n.t('app.workspaces.chat.executor.member_resend_cooldown'))
      end

      WorkspaceInvitationService.new(workspace:).resend!(member:)
      executed(message: I18n.t('app.workspaces.chat.executor.member_resend_sent', email: member.user.email))
    end

    def member_update_role(arguments:)
      member = target_member(arguments:)
      return validation_error(message: I18n.t('app.workspaces.chat.executor.member_not_found')) unless member

      role = arguments['role'].to_i
      unless Chat::Policy::EDITABLE_ROLES.include?(role)
        return validation_error(message: I18n.t('app.workspaces.chat.executor.member_role_invalid'))
      end

      member.update!(role:)
      executed(
        message: I18n.t(
          'app.workspaces.chat.executor.member_role_updated',
          name: member.user.full_name,
          role: member.role_name
        )
      )
    end

    def member_remove(arguments:) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      member = target_member(arguments:)
      return validation_error(message: I18n.t('app.workspaces.chat.executor.member_not_found')) unless member
      if member.owner?
        return validation_error(message: I18n.t('app.workspaces.chat.executor.member_remove_owner_forbidden'))
      end

      removed_user = member.user
      removed_member_was_accepted = member.status == Member::Status::ACCEPTED
      member.destroy!

      if removed_member_was_accepted
        WorkspaceMailer.workspace_member_removed(user: removed_user, workspace_name: workspace.name).deliver_now
      end

      executed(
        message: I18n.t('app.workspaces.chat.executor.member_remove_success', name: removed_user.full_name)
      )
    rescue StandardError => e
      Rails.logger.error(
        "Workspace member removal notification failed for user #{removed_user.id}: #{e.class} #{e.message}"
      )
      executed(
        message: I18n.t('app.workspaces.chat.executor.member_remove_success', name: removed_user.full_name)
      )
    end

    private

    attr_reader :workspace, :actor

    def target_member(arguments:)
      member_id = arguments['member_id'].to_i if arguments['member_id'].present?
      return workspace.members.find_by(id: member_id) if member_id

      email = arguments['email'].to_s.strip.downcase
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
        status: member_field(member[:status], fallback_key: 'member_unknown_status'),
        email_label: I18n.t('app.workspaces.settings.team.form.email_label'),
        role_label: I18n.t('app.workspaces.settings.team.table.role'),
        status_label: I18n.t('app.workspaces.settings.team.table.status')
      )
    end

    def member_field(value, fallback_key:)
      value.to_s.strip.presence || I18n.t("app.workspaces.chat.executor.#{fallback_key}")
    end

    def normalized_invite_role(raw_role)
      return nil unless raw_role.to_s.match?(/\A\d+\z/)

      raw_role.to_i
    end

    def invite_validation_error_message(first_name:, last_name:, email:, role:, raw_role:)
      return I18n.t('app.workspaces.chat.executor.member_invite_first_name_required') if first_name.blank?
      return I18n.t('app.workspaces.chat.executor.member_invite_last_name_required') if last_name.blank?
      return I18n.t('app.workspaces.chat.executor.member_invite_email_required') if email.blank?
      return I18n.t('app.workspaces.chat.executor.member_invite_already_member') if existing_member?(email:)
      return I18n.t('app.workspaces.chat.executor.member_role_invalid') if raw_role.present? && role.nil?

      nil
    end

    def validation_error(message:, code: 'validation_error')
      Result.new(status: 'validation_error', message:, data: {}, error_code: code)
    end

    def execution_error(message:, code: 'execution_error')
      Result.new(status: 'execution_error', message:, data: {}, error_code: code)
    end

    def executed(message:, data: {})
      Result.new(status: 'executed', message:, data:, error_code: nil)
    end
  end
end
