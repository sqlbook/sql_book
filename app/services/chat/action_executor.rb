# frozen_string_literal: true

module Chat
  class ActionExecutor # rubocop:disable Metrics/ClassLength
    Result = Struct.new(:status, :user_message, :data, :error_code, keyword_init: true)

    def initialize(workspace:, actor:, registry: nil)
      @workspace = workspace
      @actor = actor
      @handlers = Tooling::WorkspaceTeamHandlers.new(workspace:, actor:)
      @registry = registry || Tooling::Registry.new(
        definitions: Tooling::WorkspaceTeamRegistry.definitions(handlers: @handlers)
      )
    end

    def preflight(action_type:, payload:)
      normalized_payload = payload.to_h
      if scope_mismatch?(payload: normalized_payload)
        return forbidden_result(action_type:, reason_code: 'forbidden_scope')
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
      forbidden_result(action_type:, reason_code: 'forbidden_action')
    rescue Tooling::ValidationError => e
      validation_error_result(message: e.message, code: e.code)
    rescue ActiveRecord::RecordInvalid => e
      validation_error_result(message: e.record.errors.full_messages.to_sentence)
    rescue StandardError => e
      Rails.logger.error("Chat action failed: #{action_type} #{e.class} #{e.message}")
      execution_error_result(message: I18n.t('app.workspaces.chat.executor.unexpected_error'))
    end

    private

    attr_reader :workspace, :actor, :handlers, :registry

    def denied_result(action_type:, payload:, reason_code:)
      return validation_result(action_type:, payload:) if reason_code == 'validation_error'

      forbidden_result(action_type:, reason_code:)
    end

    def policy
      @policy ||= Chat::Policy.new(workspace:, actor:)
    end

    def map_tooling_result(execution)
      Result.new(
        status: execution.status,
        user_message: execution.message,
        data: execution.data,
        error_code: execution.error_code
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

    def validation_result(action_type:, payload:)
      case action_type
      when 'member.resend_invite'
        member_resend_validation_result(payload:)
      when 'member.update_role'
        member_role_update_validation_result(payload:)
      when 'member.remove'
        member_remove_validation_result(payload:)
      else
        validation_error_result(message: I18n.t('app.workspaces.chat.executor.member_not_found'))
      end
    end

    def member_resend_validation_result(payload:)
      member = target_member(payload:)
      return validation_error_result(message: I18n.t('app.workspaces.chat.executor.member_not_found')) unless member

      validation_error_result(message: I18n.t('app.workspaces.chat.executor.member_resend_only_pending'))
    end

    def member_role_update_validation_result(payload:)
      member = target_member(payload:)
      return validation_error_result(message: I18n.t('app.workspaces.chat.executor.member_not_found')) unless member

      requested_role = payload['role'].to_i
      unless valid_role?(requested_role)
        return validation_error_result(message: I18n.t('app.workspaces.chat.executor.member_role_invalid'))
      end

      validation_error_result(message: I18n.t('app.workspaces.chat.executor.member_role_invalid'))
    end

    def member_remove_validation_result(payload:)
      member = target_member(payload:)
      return validation_error_result(message: I18n.t('app.workspaces.chat.executor.member_not_found')) unless member
      if member.owner?
        return validation_error_result(message: I18n.t('app.workspaces.chat.executor.member_remove_owner_forbidden'))
      end

      validation_error_result(message: I18n.t('app.workspaces.chat.executor.member_not_found'))
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

    def forbidden_result(action_type:, reason_code:)
      Result.new(
        status: 'forbidden',
        user_message: forbidden_message(action_type:, reason_code:),
        data: {},
        error_code: reason_code
      )
    end

    def forbidden_message(action_type:, reason_code:)
      return I18n.t('app.workspaces.chat.executor.forbidden') if action_type.blank?
      return I18n.t('app.workspaces.chat.executor.forbidden') if reason_code == 'forbidden_action'

      I18n.t(
        'app.workspaces.chat.executor.forbidden_with_allowed_roles',
        action: I18n.t("app.workspaces.chat.executor.forbidden_actions.#{translation_action_key(action_type)}"),
        allowed_roles: I18n.t("app.workspaces.chat.executor.allowed_roles.#{allowed_roles_key(action_type)}")
      )
    rescue I18n::MissingTranslationData
      I18n.t('app.workspaces.chat.executor.forbidden')
    end

    def translation_action_key(action_type)
      action_type.tr('.', '_')
    end

    def allowed_roles_key(action_type)
      case action_type
      when 'workspace.delete'
        'owner'
      else
        'admin_or_owner'
      end
    end

    def validation_error_result(message:, code: 'validation_error')
      Result.new(
        status: 'validation_error',
        user_message: message,
        data: {},
        error_code: code
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
  end
end
