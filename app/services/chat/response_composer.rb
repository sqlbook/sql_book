# frozen_string_literal: true

module Chat
  class ResponseComposer # rubocop:disable Metrics/ClassLength
    ACTION_LABELS = {
      'workspace.update_name' => 'rename the workspace',
      'workspace.delete' => 'delete the workspace',
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

    def initialize(workspace:, actor:, prior_assistant_messages: [])
      @workspace = workspace
      @actor = actor
      @prior_assistant_messages = Array(prior_assistant_messages).compact
    end

    def compose(execution:, action_type:)
      candidate = normalized_message_candidate(build_fallback(execution:, action_type:))
      return candidate if candidate.present? && !prior_message_match?(candidate)

      alternate_candidate(execution:) || candidate
    end

    def confirmation_message(action_type:, proposed_message:, payload: {})
      named_candidate = named_confirmation_candidate(action_type:, payload:)
      return named_candidate if named_candidate.present?

      candidate = normalized_message_candidate(proposed_message)
      return candidate if candidate.present? && confirmation_prompt?(candidate)

      default_confirmation_message(action_type:)
    end

    private

    attr_reader :workspace, :actor, :prior_assistant_messages

    def build_fallback(execution:, action_type:)
      case execution.status
      when 'forbidden'
        forbidden_fallback(execution:, action_type:)
      when 'validation_error'
        validation_fallback(execution:)
      when 'execution_error'
        execution_error_fallback(execution:)
      else
        success_fallback(execution:, action_type:)
      end
    end

    def alternate_candidate(execution:)
      return nil unless execution.status == 'forbidden'

      data = execution.data.to_h
      action_label = data['action_label'] || data[:action_label] || 'that'
      allowed_roles = formatted_allowed_roles(data['allowed_roles'] || data[:allowed_roles])
      normalized_message_candidate(
        ["I can’t #{action_label} from your current permissions.", allowed_roles].compact.join("\n\n")
      )
    end

    def forbidden_fallback(execution:, action_type:) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
      data = execution.data.to_h
      action_label = data['action_label'] || data[:action_label] || inferred_action_label(action_type)
      allowed_roles = formatted_allowed_roles(
        data['allowed_roles'] || data[:allowed_roles] || inferred_allowed_roles(action_type)
      )
      detail = normalized_message_candidate(execution.fallback_message)
      return [detail, allowed_roles].compact.join("\n\n") if detail.present? && allowed_roles.present?
      return detail if detail.present?

      ["I can’t #{action_label} from your current permissions in this workspace.", allowed_roles].compact.join("\n\n")
    end

    def validation_fallback(execution:)
      normalized_message_candidate(execution.fallback_message) || generic_validation_message(execution.code)
    end

    def execution_error_fallback(execution:)
      normalized_message_candidate(execution.fallback_message) || generic_execution_error_message(execution.code)
    end

    def success_fallback(execution:, action_type:) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
      data = execution.data.to_h

      case action_type
      when 'workspace.update_name'
        "Workspace name updated to #{data['workspace_name'] || data[:workspace_name]}."
      when 'workspace.delete'
        'Workspace deleted.'
      when 'member.list'
        member_list_fallback(data:)
      when 'member.invite'
        invited_member_fallback(data:)
      when 'member.resend_invite'
        resent_member_fallback(data:)
      when 'member.update_role'
        updated_member_role_fallback(data:)
      when 'member.remove'
        removed_member_fallback(data:)
      when 'datasource.list'
        data_source_list_fallback(data:)
      when 'datasource.validate_connection'
        validated_data_source_fallback(data:)
      when 'datasource.create'
        created_data_source_fallback(data:)
      when 'query.list'
        query_list_fallback(data:)
      when 'query.save'
        query_save_fallback(data:)
      when 'query.rename'
        query_rename_fallback(data:)
      when 'query.update'
        query_update_fallback(data:)
      when 'query.delete'
        query_delete_fallback(data:)
      else
        normalized_message_candidate(execution.fallback_message) || 'Done.'
      end
    end

    def member_list_fallback(data:) # rubocop:disable Metrics/AbcSize
      members = Array(data['members'] || data[:members])
      return 'No workspace members were found.' if members.empty?

      lines = members.map do |member|
        [
          "#{member['full_name'] || member[:full_name]} (#{member['email'] || member[:email]})",
          "#{member_role_label}: #{localized_role_name(member)}",
          "#{member_status_label}: #{localized_status_name(member)}"
        ].join(' - ')
      end
      ["Found #{members.size} team members.", lines.join("\n")].join("\n\n")
    end

    def invited_member_fallback(data:)
      member = (data['invited_member'] || data[:invited_member] || {}).to_h
      "Invitation sent to #{member['email'] || member[:email]} as #{localized_role_name(member)}."
    end

    def resent_member_fallback(data:)
      member = (data['invited_member'] || data[:invited_member] || {}).to_h
      "Invitation resent to #{member['email'] || member[:email]}."
    end

    def updated_member_role_fallback(data:)
      member = (data['member'] || data[:member] || {}).to_h
      "#{member['full_name'] || member[:full_name]} is now #{localized_role_name(member)} in #{workspace.name}."
    end

    def removed_member_fallback(data:)
      member = (data['removed_member'] || data[:removed_member] || {}).to_h
      "#{member['full_name'] || member[:full_name]} has been removed from #{workspace.name}."
    end

    def data_source_list_fallback(data:) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      data_sources = Array(data['data_sources'] || data[:data_sources])
      return 'No data sources are connected to this workspace.' if data_sources.empty?

      lines = data_sources.map do |data_source|
        line = [
          data_source['name'] || data_source[:name],
          (data_source['source_type'] || data_source[:source_type]).to_s.humanize,
          (data_source['status'] || data_source[:status]).to_s.humanize
        ].join(' - ')
        tables = Array(data_source['selected_tables'] || data_source[:selected_tables]).first(6)
        tables.any? ? "#{line}\nTables: #{tables.join(', ')}" : line
      end

      ["Found #{data_sources.size} data source#{'s' unless data_sources.size == 1}.", lines.join("\n")].join("\n\n")
    end

    def validated_data_source_fallback(data:)
      count = (data['table_count'] || data[:table_count]).to_i
      "Connection validated. Found #{count} table#{'s' unless count == 1}."
    end

    def created_data_source_fallback(data:)
      data_source = (data['data_source'] || data[:data_source] || {}).to_h
      "Created data source #{data_source['name'] || data_source[:name]}."
    end

    def query_list_fallback(data:)
      queries = Array(data['queries'] || data[:queries])
      return 'There are no saved queries in this workspace yet.' if queries.empty?

      lines = queries.map do |query|
        source_name = query.dig('data_source', 'name') || query.dig(:data_source, :name)
        query_link = query_link_formatter.markdown_link(query:)
        source_name.present? ? "#{query_link} (#{source_name})" : query_link
      end

      ["Found #{queries.size} saved quer#{queries.size == 1 ? 'y' : 'ies'}.", lines.join("\n")].join("\n\n")
    end

    def query_save_fallback(data:)
      query = (data['query'] || data[:query] || {}).to_h
      outcome = data['save_outcome'] || data[:save_outcome]
      query_link = query_link_formatter.markdown_link(query:)
      return "That SQL is already saved in the query library as #{query_link}." if outcome == 'already_saved'

      "I saved that query to the query library as #{query_link}."
    end

    def query_rename_fallback(data:)
      query = (data['query'] || data[:query] || {}).to_h
      "I renamed the saved query to #{query_link_formatter.markdown_link(query:)}."
    end

    def query_update_fallback(data:) # rubocop:disable Metrics/MethodLength
      query = (data['query'] || data[:query] || {}).to_h
      outcome = data['update_outcome'] || data[:update_outcome]
      query_link = query_link_formatter.markdown_link(query:)
      case outcome
      when 'already_saved'
        "That SQL is already saved in the query library as #{query_link}."
      when 'unchanged'
        "#{query_link} is already up to date."
      else
        "I updated the saved query in the query library: #{query_link}."
      end
    end

    def query_delete_fallback(data:)
      query = (data['deleted_query'] || data[:deleted_query] || {}).to_h
      "Deleted the saved query #{query['name'] || query[:name]}."
    end

    def query_link_formatter
      @query_link_formatter ||= Queries::ChatLinkFormatter.new(workspace:)
    end

    def formatted_allowed_roles(allowed_roles) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      labels = Array(allowed_roles).map(&:to_s).map(&:strip).reject(&:empty?).map do |label|
        label.casecmp('Owner').zero? ? 'Workspace owner' : label
      end
      return nil if labels.empty?
      return 'A Workspace owner can do that.' if labels == ['Workspace owner']

      if labels.size == 1
        "#{labels.first} can do that."
      else
        "#{labels[0...-1].join(', ')}, or #{labels.last} can do that."
      end
    end

    def inferred_allowed_roles(action_type)
      Chat::Policy.allowed_roles_for(action_type).map { |role| Member.role_name_for(role, locale: :en) }
    rescue StandardError
      []
    end

    def inferred_action_label(action_type)
      ACTION_LABELS[action_type] || 'do that'
    end

    def named_confirmation_candidate(action_type:, payload:)
      return nil unless action_type == 'query.delete'

      query_name = payload.to_h['query_name'] || payload.to_h[:query_name]
      return nil if query_name.to_s.strip.blank?

      "Are you sure you want to delete the saved query #{query_name}?"
    end

    def default_confirmation_message(action_type)
      action = case action_type
               when 'workspace.delete' then 'delete this workspace'
               when 'query.delete' then 'delete this saved query'
               else
                 'do that'
               end
      "Please confirm that you want to #{action}."
    end

    def generic_validation_message(code)
      case code
      when 'query.not_found'
        'I could not find that saved query.'
      when 'member.not_found'
        'I could not find that workspace member.'
      else
        'I need a bit more information before I can do that.'
      end
    end

    def generic_execution_error_message(_code)
      'Something went wrong while carrying out that action.'
    end

    def normalized_message_candidate(value)
      value.to_s.strip.presence
    end

    def confirmation_prompt?(value)
      text = value.to_s.strip
      text.end_with?('?') || text.match?(/\bconfirm\b/i)
    end

    def prior_message_match?(candidate)
      prior_assistant_messages.any? do |message|
        message.content.to_s.strip == candidate.to_s.strip
      end
    end

    def localized_role_name(member)
      role = member['role'] || member[:role]
      fallback = member['role_name'] || member[:role_name]
      return fallback if role.blank?

      Member.role_name_for(role, locale: response_locale)
    end

    def localized_status_name(member)
      status = member['status'] || member[:status]
      fallback = member['status_name'] || member[:status_name]
      return fallback if status.blank?

      Member.status_name_for(status, locale: response_locale)
    end

    def member_role_label
      response_locale == :es ? 'Rol' : 'Role'
    end

    def member_status_label
      response_locale == :es ? 'Estado' : 'Status'
    end

    def response_locale
      @response_locale ||= actor&.preferred_locale.to_s.presence&.to_sym || I18n.locale
    end
  end
end
