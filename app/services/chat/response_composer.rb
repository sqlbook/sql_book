# frozen_string_literal: true

module Chat
  class ResponseComposer # rubocop:disable Metrics/ClassLength
    STATUS_CANDIDATE_BUILDERS = {
      'forbidden' => :forbidden_candidates,
      'validation_error' => :validation_candidates,
      'execution_error' => :execution_error_candidates
    }.freeze

    SUCCESS_CANDIDATE_BUILDERS = {
      'workspace.update_name' => :workspace_update_candidates,
      'workspace.delete' => :workspace_delete_candidates,
      'member.invite' => :member_invite_candidates,
      'member.resend_invite' => :member_resend_candidates,
      'member.update_role' => :member_role_update_candidates,
      'member.remove' => :member_remove_candidates,
      'query.save' => :query_save_candidates,
      'query.rename' => :query_rename_candidates,
      'query.delete' => :query_delete_candidates
    }.freeze

    def initialize(workspace:, actor:, prior_assistant_messages: [])
      @workspace = workspace
      @actor = actor
      @prior_assistant_messages = Array(prior_assistant_messages).compact
    end

    def compose(execution:, action_type:)
      candidates = response_candidates(execution:, action_type:)
      fallback = execution.user_message.to_s.strip
      select_candidate(candidates:, fallback:)
    end

    # rubocop:disable Metrics/CyclomaticComplexity
    def confirmation_message(action_type:, proposed_message:, payload: {})
      candidate = normalized_message_candidate(proposed_message)
      named_candidate = available_named_confirmation_candidate(action_type:, payload:)
      return named_candidate if named_candidate.present?

      return candidate if candidate.present? && confirmation_prompt?(candidate)

      default_confirmation_candidate(action_type:) || candidate.presence || default_confirmation_fallback
    rescue I18n::MissingTranslationData
      candidate.presence || default_confirmation_fallback
    end
    # rubocop:enable Metrics/CyclomaticComplexity

    private

    attr_reader :workspace, :actor, :prior_assistant_messages

    def response_candidates(execution:, action_type:)
      builder = STATUS_CANDIDATE_BUILDERS[execution.status]
      return send(builder, action_type:) if builder == :forbidden_candidates
      return send(builder, execution:) if builder
      return success_candidates(execution:, action_type:) if execution.status == 'executed'

      [execution.user_message.to_s]
    end

    def forbidden_candidates(action_type:)
      action = translated_action(action_type:)
      allowed_roles = translated_allowed_roles(action_type:)

      Array(I18n.t('app.workspaces.chat.responses.forbidden.variants')).map do |template|
        I18n.t(
          template,
          default: template,
          action:,
          allowed_roles:
        )
      end
    rescue I18n::MissingTranslationData
      [I18n.t('app.workspaces.chat.executor.forbidden')]
    end

    def validation_candidates(execution:)
      detail = execution.user_message.to_s.strip
      return [] if detail.blank?

      Array(I18n.t('app.workspaces.chat.responses.validation.variants')).map do |template|
        I18n.t(template, default: template, detail:)
      end
    rescue I18n::MissingTranslationData
      [detail]
    end

    def execution_error_candidates(execution:)
      detail = execution.user_message.to_s.strip
      return [] if detail.blank?

      Array(I18n.t('app.workspaces.chat.responses.execution_error.variants')).map do |template|
        I18n.t(template, default: template, detail:)
      end
    rescue I18n::MissingTranslationData
      [detail]
    end

    def success_candidates(execution:, action_type:)
      return [execution.user_message.to_s] if action_type == 'member.list'

      builder = SUCCESS_CANDIDATE_BUILDERS[action_type]
      return [execution.user_message.to_s] unless builder

      send(builder, execution:)
    end

    def workspace_update_candidates(execution:)
      name = execution.data.to_h['workspace_name'] || execution.data.to_h[:workspace_name] || workspace.name
      translated_variants('workspace_update_name', name:)
    end

    def workspace_delete_candidates(execution:)
      failed_notifications = execution.data.to_h['failed_notifications'] || execution.data.to_h[:failed_notifications]
      key = failed_notifications.to_i.zero? ? 'workspace_delete_success' : 'workspace_delete_partial'
      translated_variants(key)
    end

    def member_invite_candidates(execution:)
      invited_member = execution.data.to_h['invited_member'] || execution.data.to_h[:invited_member] || {}
      translated_variants(
        'member_invite',
        email: invited_member['email'] || invited_member[:email],
        role: invited_member['role_name'] || invited_member[:role_name]
      )
    end

    def member_resend_candidates(execution:)
      invited_member = execution.data.to_h['invited_member'] || execution.data.to_h[:invited_member] || {}
      translated_variants('member_resend_invite', email: invited_member['email'] || invited_member[:email])
    end

    def member_role_update_candidates(execution:)
      member = execution.data.to_h['member'] || execution.data.to_h[:member] || {}
      translated_variants(
        'member_update_role',
        name: member['full_name'] || member[:full_name],
        role: member['role_name'] || member[:role_name]
      )
    end

    def member_remove_candidates(execution:)
      member = execution.data.to_h['removed_member'] || execution.data.to_h[:removed_member] || {}
      translated_variants('member_remove', name: member['full_name'] || member[:full_name])
    end

    def query_save_candidates(execution:)
      query = execution.data.to_h['query'] || execution.data.to_h[:query] || {}
      translated_variants('query_save', name: query_link(query:))
    end

    def query_rename_candidates(execution:)
      query = execution.data.to_h['query'] || execution.data.to_h[:query] || {}
      translated_variants('query_rename', name: query_link(query:))
    end

    def query_delete_candidates(execution:)
      query = execution.data.to_h['deleted_query'] || execution.data.to_h[:deleted_query] || {}
      translated_variants('query_delete', name: query['name'] || query[:name])
    end

    def query_link(query:)
      Queries::ChatLinkFormatter.new(workspace:).markdown_link(query:)
    end

    def translated_variants(key, **args)
      Array(I18n.t("app.workspaces.chat.responses.success.#{key}.variants")).map do |template|
        I18n.t(template, default: template, **args.compact)
      end
    rescue I18n::MissingTranslationData
      []
    end

    def translated_action(action_type:)
      return I18n.t('app.navigation.settings') if action_type.blank?

      I18n.t("app.workspaces.chat.executor.forbidden_actions.#{translation_action_key(action_type)}")
    end

    def translated_allowed_roles(action_type:)
      I18n.t("app.workspaces.chat.executor.allowed_roles.#{allowed_roles_key(action_type)}")
    end

    def confirmation_candidates(action:)
      Array(I18n.t('app.workspaces.chat.responses.confirmation.variants')).map do |template|
        I18n.t(template, default: template, action:)
      end
    end

    def named_confirmation_candidate(action_type:, payload:)
      case action_type
      when 'query.delete'
        query_name = payload.to_h['query_name'] || payload.to_h[:query_name]
        return nil if query_name.to_s.strip.blank?

        I18n.t('app.workspaces.chat.responses.confirmation.query_delete_named', name: query_name)
      end
    rescue I18n::MissingTranslationData
      nil
    end

    def available_named_confirmation_candidate(action_type:, payload:)
      candidate = named_confirmation_candidate(action_type:, payload:)
      return nil if candidate.blank?
      return nil if prior_message_match?(candidate)

      candidate
    end

    def default_confirmation_candidate(action_type:)
      action = translated_action(action_type:)
      confirmation_candidates(action:).find { |value| !prior_message_match?(value) }
    end

    def default_confirmation_fallback
      I18n.t('app.workspaces.chat.messages.confirmation_default')
    end

    def translation_action_key(action_type)
      action_type.to_s.tr('.', '_')
    end

    def allowed_roles_key(action_type)
      Chat::Policy.allowed_roles_key_for(action_type)
    end

    def select_candidate(candidates:, fallback:)
      viable_candidates = Array(candidates).map { |value| value.to_s.strip }.compact_blank
      viable_candidates.each do |candidate|
        return candidate unless prior_message_match?(candidate)
      end

      fallback.presence || viable_candidates.first || ''
    end

    def prior_message_match?(candidate)
      normalized_candidate = normalize_text(candidate)
      prior_assistant_messages.any? do |message|
        normalize_text(message.content.to_s) == normalized_candidate
      end
    end

    def normalize_text(text)
      text.to_s.downcase.gsub(/\s+/, ' ').gsub(/[[:punct:]]+/, '').strip
    end

    def confirmation_prompt?(content)
      content.to_s.downcase.match?(/\b(confirm|confirmed|confirmation|confirma|confirmar)\b/)
    end

    def normalized_message_candidate(value)
      case value
      when Array
        value.flatten.filter_map do |entry|
          normalized_message_candidate(entry)
        end.first.to_s.strip
      else
        value.to_s.strip
      end
    end
  end
end
