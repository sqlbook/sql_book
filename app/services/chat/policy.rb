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
      datasource.list
      datasource.validate_connection
      datasource.create
      query.list
      query.run
      query.save
      query.rename
      query.delete
    ].freeze

    WRITE_ACTIONS = ALLOWED_ACTIONS - ['member.list', 'datasource.list', 'query.list', 'query.run']

    BLOCKED_PREFIXES = %w[
      workspace.list
      workspace.get
      workspace.create
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
      'member.remove' => :authorize_member_remove,
      'datasource.list' => :authorize_data_source_list,
      'datasource.validate_connection' => :authorize_data_source_validate_connection,
      'datasource.create' => :authorize_data_source_create,
      'query.list' => :authorize_query_list,
      'query.run' => :authorize_query_run,
      'query.save' => :authorize_query_save,
      'query.rename' => :authorize_query_rename,
      'query.delete' => :authorize_query_delete
    }.freeze

    def self.write_action?(action_type)
      WRITE_ACTIONS.include?(action_type)
    end

    def self.allowed_roles_key_for(action_type)
      return 'owner' if action_type == 'workspace.delete'
      return 'workspace_member' if action_type == 'query.list'
      return 'user_admin_or_owner' if action_type == 'query.run'
      return 'user_admin_or_owner' if action_type == 'query.save'
      return 'user_admin_or_owner' if action_type == 'query.rename'
      return 'user_admin_or_owner' if action_type == 'query.delete'

      'admin_or_owner'
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
      return allow if can_view_members?

      deny(reason_code: 'forbidden_role')
    end

    def authorize_member_invite(payload:)
      return deny(reason_code: 'forbidden_role') unless can_manage_members?

      requested_role = normalized_role(payload['role'])
      return allow if payload['role'].blank? || requested_role.nil?
      return deny(reason_code: 'forbidden_role') unless EDITABLE_ROLES.include?(requested_role)
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

    def authorize_data_source_list(**)
      authorize_data_source_management
    end

    def authorize_data_source_validate_connection(**)
      authorize_data_source_management
    end

    def authorize_data_source_create(**)
      authorize_data_source_management
    end

    def authorize_query_run(**)
      return allow if capabilities.can_write_queries?

      deny(reason_code: 'forbidden_role')
    end

    def authorize_query_list(**)
      return allow if capabilities.can_view_queries?

      deny(reason_code: 'forbidden_role')
    end

    def authorize_query_save(**)
      return allow if capabilities.can_write_queries?

      deny(reason_code: 'forbidden_role')
    end

    def authorize_query_rename(payload:)
      query = target_query(payload:)
      return deny(reason_code: 'validation_error') if query.nil?
      return allow if capabilities.can_write_queries?

      deny(reason_code: 'forbidden_role')
    end

    def authorize_query_delete(payload:)
      query = target_query(payload:)
      return deny(reason_code: 'validation_error') if query.nil?
      return allow if capabilities.can_destroy_query?(query:)

      deny(reason_code: 'forbidden_role')
    end

    def current_role
      @current_role ||= capabilities.role
    end

    def can_manage_workspace?
      capabilities.can_manage_workspace_settings?
    end

    def can_manage_members?
      capabilities.can_manage_workspace_members?
    end

    def can_view_members?
      capabilities.can_view_team_members?
    end

    def can_manage_data_sources?
      capabilities.can_manage_data_sources?
    end

    def can_manage_member?(member:)
      current_role < member.role
    end

    def higher_than_actor_role?(requested_role:)
      requested_role < current_role
    end

    def target_member(payload:)
      member_reference_resolver.resolve(payload:)
    end

    def authorize_data_source_management
      return allow if can_manage_data_sources?

      deny(reason_code: 'forbidden_role')
    end

    def normalized_role(role)
      role.to_i if role.to_s.match?(/\A\d+\z/)
    end

    def member_reference_resolver
      @member_reference_resolver ||= Chat::MemberReferenceResolver.new(workspace:)
    end

    def target_query(payload:)
      query_id = payload['query_id'].to_i if payload['query_id'].present?
      return nil unless query_id

      Queries::LibraryService.new(workspace:).call.find { |query| query.id == query_id }
    end

    def capabilities
      @capabilities ||= WorkspaceCapabilityResolver.new(workspace:, actor:)
    end

    def allow
      Decision.new(allowed: true, reason_code: nil, effective_role: current_role)
    end

    def deny(reason_code:)
      Decision.new(allowed: false, reason_code:, effective_role: current_role)
    end
  end
end
