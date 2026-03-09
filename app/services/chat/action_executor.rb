# frozen_string_literal: true

module Chat
  class ActionExecutor
    Result = Struct.new(:status, :user_message, :data, :error_code, keyword_init: true)

    def initialize(workspace:, actor:, registry: nil)
      @workspace = workspace
      @actor = actor
      @handlers = Tooling::WorkspaceTeamHandlers.new(workspace:, actor:)
      @registry = registry || Tooling::Registry.new(
        definitions: Tooling::WorkspaceTeamRegistry.definitions(handlers: @handlers)
      )
    end

    def execute(action_type:, payload:) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      normalized_payload = payload.to_h
      return forbidden_result(reason_code: 'forbidden_scope') if scope_mismatch?(payload: normalized_payload)

      decision = policy.authorize(action_type:, payload: normalized_payload)
      return forbidden_result(reason_code: decision.reason_code) unless decision.allowed

      execution = registry.execute(name: action_type, arguments: normalized_payload)
      map_tooling_result(execution)
    rescue Tooling::UnknownToolError
      forbidden_result(reason_code: 'forbidden_action')
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

    def forbidden_result(reason_code:)
      Result.new(
        status: 'forbidden',
        user_message: I18n.t('app.workspaces.chat.executor.forbidden'),
        data: {},
        error_code: reason_code
      )
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
