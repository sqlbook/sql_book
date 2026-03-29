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
      return validation_error(code: 'workspace.name_required') if name.blank?

      workspace.update!(name:)
      data = { 'workspace_name' => workspace.name }
      executed(code: 'workspace.updated_name', data:, fallback_message: "Workspace name updated to #{workspace.name}.")
    end

    def workspace_delete(*) # rubocop:disable Metrics/MethodLength
      result = WorkspaceDeletionService.new(workspace:, deleted_by: actor).call
      unless result.success?
        return execution_error(code: 'workspace.delete_failed',
                               fallback_message: 'Workspace deletion failed.')
      end

      partial = result.failed_notifications.positive?
      data = {
        'redirect_path' => '/app/workspaces',
        'failed_notifications' => result.failed_notifications
      }
      fallback_message = if partial
                           'Workspace deleted, but some notifications could not be sent.'
                         else
                           'Workspace deleted.'
                         end

      executed(code: partial ? 'workspace.deleted_partial' : 'workspace.deleted', data:, fallback_message:)
    end

    def member_list(*)
      members = workspace.members.includes(:user).map { |member| member_payload(member:) }
      fallback_message = member_list_fallback(members:)

      executed(
        code: 'member.listed',
        data: { 'members' => members, 'count' => members.size },
        fallback_message:
      )
    end

    def member_invite(arguments:) # rubocop:disable Metrics/AbcSize
      email = arguments['email'].to_s.strip.downcase
      first_name = arguments['first_name'].to_s.strip
      last_name = arguments['last_name'].to_s.strip
      role = normalized_invite_role(arguments['role'])
      validation_code = invite_validation_code(
        first_name:,
        last_name:,
        email:,
        role:,
        raw_role: arguments['role']
      )
      return validation_error(code: validation_code, data: invite_validation_data(email:, role:)) if validation_code

      member = WorkspaceInvitationService.new(workspace:).invite!(
        invited_by: actor,
        first_name:,
        last_name:,
        email:,
        role:
      )
      payload = member_payload(member:)

      executed(
        code: 'member.invited',
        data: { 'invited_member' => payload },
        fallback_message: "Invitation sent to #{email} as #{payload['role_name']}."
      )
    end

    def member_resend_invite(arguments:) # rubocop:disable Metrics/AbcSize
      member = target_member(arguments:)
      return validation_error(code: 'member.not_found') unless member

      return validation_error(code: 'member.resend.pending_only') unless member.pending?

      if member.updated_at > RESEND_COOLDOWN.ago
        remaining_seconds = (member.updated_at + RESEND_COOLDOWN - Time.current).ceil
        return validation_error(
          code: 'member.resend.cooldown_active',
          data: { 'retry_after_seconds' => [remaining_seconds, 0].max }
        )
      end

      WorkspaceInvitationService.new(workspace:).resend!(member:)
      payload = member_payload(member:)

      executed(
        code: 'member.invite_resent',
        data: { 'invited_member' => payload },
        fallback_message: "Invitation resent to #{payload['email']}."
      )
    end

    def member_update_role(arguments:)
      member = target_member(arguments:)
      return validation_error(code: 'member.not_found') unless member

      role = arguments['role'].to_i
      return validation_error(code: 'member.role.invalid') unless Chat::Policy::EDITABLE_ROLES.include?(role)

      member.update!(role:)
      payload = member_payload(member: member.reload)

      executed(
        code: 'member.role.updated',
        data: { 'member' => payload },
        fallback_message: "#{payload['full_name']} is now #{payload['role_name']} in #{workspace.name}."
      )
    end

    def member_remove(arguments:) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      member = target_member(arguments:)
      return validation_error(code: 'member.not_found') unless member
      return validation_error(code: 'member.remove.owner_forbidden') if member.owner?

      removed_user = member.user
      removed_member_was_accepted = member.status == Member::Status::ACCEPTED
      removed_member_payload = member_payload(member:)
      member.destroy!

      if removed_member_was_accepted
        WorkspaceMailer.workspace_member_removed(user: removed_user, workspace_name: workspace.name).deliver_now
      end

      executed(
        code: 'member.removed',
        data: { 'removed_member' => removed_member_payload },
        fallback_message: "#{removed_member_payload['full_name']} was removed from #{workspace.name}."
      )
    rescue StandardError => e
      Rails.logger.error(
        "Workspace member removal notification failed for user #{removed_user.id}: #{e.class} #{e.message}"
      )
      executed(
        code: 'member.removed',
        data: { 'removed_member' => removed_member_payload },
        fallback_message: "#{removed_member_payload['full_name']} was removed from #{workspace.name}."
      )
    end

    private

    attr_reader :workspace, :actor

    def target_member(arguments:)
      member_reference_resolver.resolve(payload: arguments)
    end

    def existing_member?(email:)
      workspace.members.joins(:user).exists?(users: { email: })
    end

    def member_reference_resolver
      @member_reference_resolver ||= Chat::MemberReferenceResolver.new(workspace:)
    end

    def member_payload(member:) # rubocop:disable Metrics/AbcSize
      {
        'member_id' => member.id,
        'email' => member.user&.email.to_s,
        'first_name' => member.user&.first_name.to_s,
        'last_name' => member.user&.last_name.to_s,
        'full_name' => member.user&.full_name.to_s,
        'role' => member.role,
        'role_name' => Member.role_name_for(member.role, locale: :en),
        'status' => member.status,
        'status_name' => Member.status_name_for(member.status, locale: :en)
      }
    end

    def member_list_fallback(members:)
      return 'No workspace members were found.' if members.empty?

      lines = members.map do |member|
        "#{member['full_name']} (#{member['email']}) - #{member['role_name']}, #{member['status_name']}"
      end

      ["Found #{members.size} team members.", lines.join("\n")].join("\n\n")
    end

    def normalized_invite_role(raw_role)
      return nil unless raw_role.to_s.match?(/\A\d+\z/)

      raw_role.to_i
    end

    def invite_validation_code(first_name:, last_name:, email:, role:, raw_role:) # rubocop:disable Metrics/CyclomaticComplexity
      return 'member.invite.first_name_required' if first_name.blank?
      return 'member.invite.last_name_required' if last_name.blank?
      return 'member.invite.email_required' if email.blank?
      return 'member.invite.role_required' if raw_role.blank?
      return 'member.invite.already_member' if existing_member?(email:)
      return 'member.role.invalid' if raw_role.present? && role.nil?

      nil
    end

    def invite_validation_data(email:, role:)
      {
        'email' => email.presence,
        'role' => role
      }.compact
    end

    def validation_error(code:, data: {}, fallback_message: nil)
      Result.new(
        status: 'validation_error',
        code:,
        data: data,
        fallback_message: fallback_message || validation_fallback_message(code:, data:)
      )
    end

    def execution_error(code:, data: {}, fallback_message: nil)
      Result.new(
        status: 'execution_error',
        code:,
        data: data,
        fallback_message:
      )
    end

    def executed(code:, data: {}, fallback_message: nil)
      Result.new(
        status: 'executed',
        code:,
        data: data,
        fallback_message:
      )
    end

    def validation_fallback_message(code:, data:) # rubocop:disable Metrics/CyclomaticComplexity, Metrics/MethodLength
      case code
      when 'workspace.name_required'
        'Please provide a workspace name.'
      when 'member.not_found'
        'I could not find that workspace member.'
      when 'member.resend.pending_only'
        'Only pending invitations can be resent.'
      when 'member.resend.cooldown_active'
        seconds = data.to_h['retry_after_seconds'].to_i
        minutes = [(seconds / 60.0).ceil, 1].max
        "That invitation was resent recently. Please wait about #{minutes} #{minute_label(minutes)} and try again."
      when 'member.role.invalid'
        'Please choose a valid member role.'
      when 'member.remove.owner_forbidden'
        'Workspace owners cannot be removed.'
      when 'member.invite.first_name_required'
        'Please provide a first name.'
      when 'member.invite.last_name_required'
        'Please provide a last name.'
      when 'member.invite.email_required'
        'Please provide a valid email address.'
      when 'member.invite.role_required'
        'Please provide a role for the new member.'
      when 'member.invite.already_member'
        'That email address is already a workspace member.'
      else
        'I could not complete that member action.'
      end
    end

    def minute_label(count)
      count == 1 ? 'minute' : 'minutes'
    end
  end
end
