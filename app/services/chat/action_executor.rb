# frozen_string_literal: true

module Chat
  class ActionExecutor # rubocop:disable Metrics/ClassLength
    ACTION_LABELS = {
      'workspace.update_name' => 'rename the workspace',
      'workspace.delete' => 'delete the workspace',
      'thread.rename' => 'rename this chat',
      'member.list' => 'view the team members list',
      'member.invite' => 'invite workspace members',
      'member.resend_invite' => 'resend workspace invitations',
      'member.update_role' => 'change workspace member roles',
      'member.remove' => 'remove workspace members',
      'datasource.list' => 'view data sources',
      'datasource.validate_connection' => 'validate a data source connection',
      'datasource.create' => 'create a data source',
      'query.list' => 'view saved queries',
      'query.run' => 'run a query',
      'query.save' => 'save a query',
      'query.rename' => 'rename a query',
      'query.update' => 'update a query',
      'query.delete' => 'delete a query'
    }.freeze

    class Result
      DEFAULT_CODES = {
        'executed' => 'tool.executed',
        'validation_error' => 'tool.validation_error',
        'execution_error' => 'tool.execution_error',
        'forbidden' => 'tool.forbidden'
      }.freeze

      attr_reader :status, :code, :data, :fallback_message

      def initialize(status:, code: nil, data: {}, fallback_message: nil, **legacy)
        @status = status
        @code = code.presence || legacy[:error_code].presence || DEFAULT_CODES[status.to_s] || 'tool.unknown'
        @data = data || {}
        @fallback_message = (fallback_message.presence || legacy[:user_message].presence).to_s.strip.presence
      end

      def user_message
        fallback_message
      end

      def error_code
        return code unless code.to_s.include?('.')

        _namespace, remainder = code.to_s.split('.', 2)
        remainder.to_s.tr('.', '_')
      end
    end

    def initialize(workspace:, actor:, registry: nil)
      @workspace = workspace
      @actor = actor
      @handlers = {
        team: Tooling::WorkspaceTeamHandlers.new(workspace:, actor:),
        chat_threads: Tooling::WorkspaceChatThreadHandlers.new(workspace:, actor:),
        data_sources: Tooling::WorkspaceDataSourceHandlers.new(workspace:, actor:),
        queries: Tooling::WorkspaceQueryHandlers.new(workspace:, actor:)
      }
      @registry = registry || Tooling::Registry.new(
        definitions: Tooling::WorkspaceRegistry.definitions(handlers: @handlers)
      )
    end

    def preflight(action_type:, payload:)
      normalized_payload = payload.to_h
      if scope_mismatch?(payload: normalized_payload)
        return forbidden_result(action_type:, reason_code: 'forbidden_scope', payload: normalized_payload)
      end

      decision = policy.authorize(action_type:, payload: normalized_payload)
      return nil if decision.allowed

      denied_result(action_type:, payload: normalized_payload, reason_code: decision.reason_code)
    end

    def execute(action_type:, payload:) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      normalized_payload = payload.to_h
      preflight_result = preflight(action_type:, payload: normalized_payload)
      return preflight_result if preflight_result

      execution = registry.execute(name: action_type, arguments: normalized_payload)
      map_tooling_result(execution)
    rescue Tooling::UnknownToolError
      forbidden_result(action_type:, reason_code: 'forbidden_action', payload: normalized_payload)
    rescue Tooling::ValidationError => e
      validation_error_result(code: e.code, fallback_message: e.message)
    rescue ActiveRecord::RecordInvalid => e
      validation_error_result(code: 'validation.record_invalid',
                              fallback_message: e.record.errors.full_messages.to_sentence)
    rescue StandardError => e
      Rails.logger.error("Chat action failed: #{action_type} #{e.class} #{e.message}")
      execution_error_result(message: 'Something went wrong while carrying out that action.')
    end

    private

    attr_reader :workspace, :actor, :handlers, :registry

    def denied_result(action_type:, payload:, reason_code:)
      return validation_result(action_type:, payload:) if reason_code == 'validation_error'

      forbidden_result(action_type:, reason_code:, payload:)
    end

    def policy
      @policy ||= Chat::Policy.new(workspace:, actor:)
    end

    def map_tooling_result(execution)
      Result.new(
        status: execution.status,
        code: execution.code,
        data: execution.data,
        fallback_message: execution.fallback_message
      )
    end

    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    def scope_mismatch?(payload:)
      payload_workspace_id = payload['workspace_id'].to_i if payload['workspace_id'].present?
      return true if payload_workspace_id && payload_workspace_id != workspace.id

      payload_thread_id = payload['thread_id'].to_i if payload['thread_id'].present?
      return true if payload_thread_id && !workspace.chat_threads.active.for_user(actor).exists?(id: payload_thread_id)

      payload_message_id = payload['message_id'].to_i if payload['message_id'].present?
      return false unless payload_message_id

      user_message_scope = workspace.chat_messages
        .joins(:chat_thread)
        .where(chat_threads: { created_by_id: actor.id })

      !user_message_scope.exists?(id: payload_message_id)
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

    def validation_result(action_type:, payload:) # rubocop:disable Metrics/MethodLength
      case action_type
      when 'thread.rename'
        thread_rename_validation_result(payload:)
      when 'member.resend_invite'
        member_resend_validation_result(payload:)
      when 'member.update_role'
        member_role_update_validation_result(payload:)
      when 'member.remove'
        member_remove_validation_result(payload:)
      else
        validation_error_result(code: 'validation.unresolved_target')
      end
    end

    def member_resend_validation_result(payload:)
      member = target_member(payload:)
      return validation_error_result(code: 'member.not_found') unless member

      validation_error_result(code: 'member.resend.pending_only')
    end

    def member_role_update_validation_result(payload:)
      member = target_member(payload:)
      return validation_error_result(code: 'member.not_found') unless member

      requested_role = payload['role'].to_i
      return validation_error_result(code: 'member.role.invalid') unless valid_role?(requested_role)

      validation_error_result(code: 'member.role.invalid')
    end

    def member_remove_validation_result(payload:)
      member = target_member(payload:)
      return validation_error_result(code: 'member.not_found') unless member
      return validation_error_result(code: 'member.remove.owner_forbidden') if member.owner?

      validation_error_result(code: 'member.not_found')
    end

    def target_member(payload:)
      member_reference_resolver.resolve(payload:)
    end

    def member_reference_resolver
      @member_reference_resolver ||= Chat::MemberReferenceResolver.new(workspace:)
    end

    def valid_role?(role)
      Chat::Policy::EDITABLE_ROLES.include?(role)
    end

    def thread_rename_validation_result(payload:)
      return validation_error_result(code: 'thread.not_found') if payload['thread_id'].to_i.zero?
      return validation_error_result(code: 'thread.title_required') if payload['title'].to_s.strip.blank?

      validation_error_result(code: 'thread.validation_error')
    end

    def forbidden_result(action_type:, reason_code:, payload:)
      Result.new(
        status: 'forbidden',
        code: forbidden_code(reason_code:),
        data: forbidden_data(action_type:, reason_code:, payload:),
        fallback_message: forbidden_message(action_type:, reason_code:, payload:)
      )
    end

    def forbidden_message(action_type:, reason_code:, payload:)
      return 'This action is not available in this workspace chat.' if action_type.blank?
      return 'This action is not available in this workspace chat.' if reason_code == 'forbidden_action'
      if action_type == 'thread.rename' && reason_code == 'forbidden_scope'
        return 'You can only rename your own chat thread in this workspace.'
      end

      allowed_roles = allowed_roles_for(action_type:, payload:)
      return 'You do not have permission to do that in this workspace.' if allowed_roles.blank?

      [
        "You do not have permission to #{human_action_label(action_type)} in this workspace.",
        allowed_roles_sentence(allowed_roles)
      ].join(' ')
    end

    def forbidden_code(reason_code:)
      "policy.#{reason_code.presence || 'forbidden'}"
    end

    def forbidden_data(action_type:, reason_code:, payload:)
      data = {
        'action_type' => action_type,
        'action_label' => human_action_label(action_type)
      }
      return data if reason_code == 'forbidden_scope'

      allowed_roles = allowed_roles_for(action_type:, payload:)
      data['allowed_roles'] = allowed_roles if allowed_roles.present?
      data
    end

    def target_specific_allowed_roles(action_type:, payload:)
      return nil unless action_type == 'member.update_role'
      return nil unless actor_workspace_role == Member::Roles::ADMIN

      target_member = target_member(payload:)
      return nil unless target_member&.role == Member::Roles::ADMIN

      ['owner']
    end

    def actor_workspace_role
      @actor_workspace_role ||= WorkspaceCapabilityResolver.new(workspace:, actor:).role
    end

    def allowed_roles_for(action_type:, payload:)
      target_specific_allowed_roles(action_type:, payload:) || allowed_role_names(action_type:)
    end

    def allowed_role_names(action_type)
      Chat::Policy.allowed_roles_for(action_type).map { |role| Member.role_name_for(role, locale: :en) }.compact
    end

    def human_action_label(action_type)
      ACTION_LABELS[action_type] || 'perform that action'
    end

    def allowed_roles_sentence(allowed_roles)
      labels = Array(allowed_roles).compact
      return '' if labels.empty?
      return 'A Workspace owner can do that.' if [['Owner'], ['owner']].include?(labels)

      if labels.size == 1
        "#{labels.first} can do that."
      else
        "#{labels[0...-1].join(', ')}, or #{labels.last} can do that."
      end
    end

    def validation_error_result(code:, data: {}, fallback_message: nil)
      Result.new(
        status: 'validation_error',
        code:,
        data:,
        fallback_message:
      )
    end

    def execution_error_result(message:, code: 'tool.execution_error', data: {})
      Result.new(
        status: 'execution_error',
        code:,
        data:,
        fallback_message: message
      )
    end
  end
end
