# frozen_string_literal: true

module Chat
  class ExecutionTruthReconciler
    def initialize(workspace:)
      @workspace = workspace
    end

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def call(action_type:, payload:, execution:)
      return execution unless execution.status == 'executed'

      data = case action_type
             when 'workspace.update_name'
               execution.data.to_h.merge(workspace_name: workspace.reload.name)
             when 'member.invite', 'member.resend_invite'
               execution.data.to_h.merge(
                 'invited_member' => refreshed_member_snapshot(payload:, execution:, key: 'invited_member')
               )
             when 'member.update_role'
               execution.data.to_h.merge('member' => refreshed_member_snapshot(payload:, execution:, key: 'member'))
             when 'member.remove'
               execution.data.to_h.merge('removed_member' => removed_member_snapshot(execution:))
             else
               execution.data
             end

      Chat::ActionExecutor::Result.new(
        status: execution.status,
        user_message: execution.user_message,
        data:,
        error_code: execution.error_code
      )
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    private

    attr_reader :workspace

    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    def refreshed_member_snapshot(payload:, execution:, key:)
      candidate = execution.data.to_h[key] || execution.data.to_h[key.to_sym] || {}
      member = member_reference_resolver.resolve(payload: candidate) ||
               member_reference_resolver.resolve(payload:) ||
               member_reference_resolver.resolve(text: payload['email'].to_s)
      return candidate if member.nil?

      {
        'member_id' => member.id,
        'email' => member.user&.email.to_s,
        'first_name' => member.user&.first_name.to_s,
        'last_name' => member.user&.last_name.to_s,
        'full_name' => member.user&.full_name.to_s,
        'role' => member.role,
        'role_name' => member.role_name,
        'status' => member.status,
        'status_name' => member.status_name
      }
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

    def member_reference_resolver
      @member_reference_resolver ||= MemberReferenceResolver.new(workspace:)
    end

    def removed_member_snapshot(execution:)
      execution.data.to_h['removed_member'] || execution.data.to_h[:removed_member] || {}
    end
  end
end
