# frozen_string_literal: true

module Chat
  class Policy # rubocop:disable Metrics/ClassLength
    Decision = Struct.new(:allowed, :reason_code, :effective_role, keyword_init: true)

    ALLOWED_ACTIONS = %w[
      workspace.update_name
      workspace.delete
      member.list
      member.invite
      member.resend_invite
      member.update_role
      member.remove
    ].freeze

    WRITE_ACTIONS = ALLOWED_ACTIONS - ['member.list']

    BLOCKED_PREFIXES = %w[
      workspace.list
      workspace.get
      workspace.create
      datasource.
      query.
      dashboard.
      billing.
      subscription.
      admin.
      super_admin.
    ].freeze

    EDITABLE_ROLES = [Member::Roles::ADMIN, Member::Roles::USER, Member::Roles::READ_ONLY].freeze
    ACTION_HANDLERS = {
      'workspace.update_name' => :authorize_workspace_update_name,
      'workspace.delete' => :authorize_workspace_delete,
      'member.list' => :authorize_member_list,
      'member.invite' => :authorize_member_invite,
      'member.resend_invite' => :authorize_member_resend,
      'member.update_role' => :authorize_member_role_update,
      'member.remove' => :authorize_member_remove
    }.freeze

    def self.write_action?(action_type)
      WRITE_ACTIONS.include?(action_type)
    end

    def initialize(workspace:, actor:)
      @workspace = workspace
      @actor = actor
    end

    def authorize(action_type:, payload:)
      return deny(reason_code: 'forbidden_action') unless allowed_action?(action_type:)
      return deny(reason_code: 'forbidden_scope') if current_role.nil?

      handler = ACTION_HANDLERS[action_type]
      return deny(reason_code: 'forbidden_action') unless handler

      send(handler, payload: payload.to_h)
    end

    private

    attr_reader :workspace, :actor

    def allowed_action?(action_type:)
      return false if action_type.blank?
      return false if BLOCKED_PREFIXES.any? { |prefix| action_type.start_with?(prefix) }

      ALLOWED_ACTIONS.include?(action_type)
    end

    def authorize_workspace_update_name(**)
      return allow if can_manage_workspace?

      deny(reason_code: 'forbidden_role')
    end

    def authorize_workspace_delete(**)
      return allow if current_role == Member::Roles::OWNER

      deny(reason_code: 'forbidden_role')
    end

    def authorize_member_list(**)
      allow
    end

    def authorize_member_invite(payload:)
      return deny(reason_code: 'forbidden_role') unless can_manage_members?

      requested_role = normalized_role(payload['role'])
      return deny(reason_code: 'validation_error') unless EDITABLE_ROLES.include?(requested_role)
      return deny(reason_code: 'forbidden_role') if higher_than_actor_role?(requested_role:)

      allow
    end

    def authorize_member_resend(payload:)
      return deny(reason_code: 'forbidden_role') unless can_manage_members?

      member = target_member(payload:)
      return deny(reason_code: 'validation_error') unless member&.pending?
      return deny(reason_code: 'forbidden_role') unless can_manage_member?(member:)

      allow
    end

    def authorize_member_role_update(payload:)
      return deny(reason_code: 'forbidden_role') unless can_manage_members?

      member = target_member(payload:)
      requested_role = normalized_role(payload['role'])
      return deny(reason_code: 'validation_error') if member.nil? || requested_role.nil?
      return deny(reason_code: 'validation_error') unless EDITABLE_ROLES.include?(requested_role)
      return deny(reason_code: 'forbidden_role') unless can_manage_member?(member:)
      return deny(reason_code: 'forbidden_role') if higher_than_actor_role?(requested_role:)

      allow
    end

    def authorize_member_remove(payload:)
      return deny(reason_code: 'forbidden_role') unless can_manage_members?

      member = target_member(payload:)
      return deny(reason_code: 'validation_error') if member.nil? || member.owner?
      return deny(reason_code: 'forbidden_role') unless can_manage_member?(member:)

      allow
    end

    def current_role
      @current_role ||= workspace.members.find_by(user_id: actor.id)&.role
    end

    def can_manage_workspace?
      [Member::Roles::OWNER, Member::Roles::ADMIN].include?(current_role)
    end

    def can_manage_members?
      can_manage_workspace?
    end

    def can_manage_member?(member:)
      current_role < member.role
    end

    def higher_than_actor_role?(requested_role:)
      requested_role < current_role
    end

    def target_member(payload:)
      member_id = payload['member_id'].to_i if payload['member_id'].present?
      return workspace.members.find_by(id: member_id) if member_id

      email = payload['email'].to_s.strip.downcase
      return nil if email.blank?

      workspace.members.joins(:user).find_by(users: { email: })
    end

    def normalized_role(role)
      role.to_i if role.to_s.match?(/\A\d+\z/)
    end

    def allow
      Decision.new(allowed: true, reason_code: nil, effective_role: current_role)
    end

    def deny(reason_code:)
      Decision.new(allowed: false, reason_code:, effective_role: current_role)
    end
  end
end
