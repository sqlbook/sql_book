# frozen_string_literal: true

module Chat
  class ConversationContextResolver # rubocop:disable Metrics/ClassLength
    PRONOUN_REFERENCE_REGEX = /
      \b(
        him|her|them|they|their|
        that\s+(?:person|member|user)|
        this\s+(?:person|member|user)
      )\b
    /ix
    GENERIC_REFERENCE_REGEX = /\b(which|what|who)\b.*\b(user|person|member|invite)\b/i
    CLARIFICATION_REGEX = /\b(are\s+you\s+sure|really|seriously)\b/i
    ROLE_QUESTION_REGEX = /\b(role|admin|user|read\s*only|readonly)\b/i
    STATUS_QUESTION_REGEX = /\b(accepted|accept|pending|joined|join|in\s+the\s+workspace|already\s+in|status|invite)\b/i

    def initialize(workspace:, conversation_messages:)
      @workspace = workspace
      @conversation_messages = Array(conversation_messages).compact
    end

    def recent_invited_member
      recent_result_payload('invited_member')
    end

    def recent_removed_member
      recent_result_payload('removed_member')
    end

    def recent_updated_member
      recent_result_payload('member')
    end

    def recent_member_reference(text:)
      candidate = explicit_reference_match(text:)
      return candidate if candidate
      return latest_member_reference if referential_follow_up?(text:)

      nil
    end

    def recent_invited_member_for_role_question(text:)
      invited_member = recent_invited_member
      return nil unless invited_member

      current_member = current_member_snapshot(member: invited_member)
      return current_member || invited_member if pronoun_reference?(text:)

      matched = member_matches_text?(member: invited_member, text:)
      return nil unless matched

      current_member || invited_member
    end

    def role_question_context_active?(text:)
      role_question?(text:) || recent_user_role_question?
    end

    def identity_question?(text:)
      text.to_s.match?(GENERIC_REFERENCE_REGEX)
    end

    def status_question?(text:)
      text.to_s.match?(STATUS_QUESTION_REGEX)
    end

    def clarification_question?(text:)
      text.to_s.match?(CLARIFICATION_REGEX)
    end

    def current_member_for_recent_reference(text:)
      member = recent_member_reference(text:) || latest_member_reference
      return nil unless member

      current_member_snapshot(member:)
    end

    def invite_seed_details(text:)
      member = recent_member_reference(text:) || recent_removed_member || recent_invited_member
      return {} unless member

      {
        'email' => member['email'].to_s,
        'first_name' => member['first_name'].to_s,
        'last_name' => member['last_name'].to_s,
        'full_name' => member['full_name'].to_s
      }.compact_blank
    end

    def structured_context_lines # rubocop:disable Metrics/MethodLength
      lines = []

      if (member = recent_invited_member)
        lines << structured_member_line(prefix: 'Recent invited member', member:)
        if (current_member = current_member_snapshot(member:))
          lines << structured_member_line(
            prefix: 'Current workspace state for recent invited member',
            member: current_member
          )
        end
      end
      if (member = recent_removed_member)
        lines << structured_member_line(prefix: 'Recent removed member', member:)
      end
      if (member = recent_updated_member)
        lines << structured_member_line(prefix: 'Recent updated member', member:)
      end

      lines.uniq
    end

    private

    attr_reader :conversation_messages, :workspace

    def recent_result_payload(key)
      conversation_messages.reverse_each do |entry|
        payload = result_data(entry)[key] || result_data(entry)[key.to_sym]
        return payload.stringify_keys if payload.is_a?(Hash)
      end

      nil
    end

    def latest_member_reference
      recent_member_references.first
    end

    def recent_member_references
      @recent_member_references ||= conversation_messages.reverse_each.filter_map do |entry|
        result_payload(entry:)
      end
    end

    def result_payload(entry:)
      result_data(entry).values.find { |value| value.is_a?(Hash) }&.stringify_keys
    end

    def explicit_reference_match(text:)
      reference_text = text.to_s
      member_candidates.find do |member|
        member_matches_text?(member:, text: reference_text)
      end
    end

    def member_candidates
      recent_member_references
        .compact
        .uniq { |member| member['email'].to_s.downcase.presence || member['full_name'].to_s.downcase }
    end

    def member_matches_text?(member:, text:)
      reference_text = text.to_s
      return member if member['full_name'].present? && reference_text.match?(member_name_regex(member['full_name']))
      return member if member['email'].present? && reference_text.match?(/\b#{Regexp.escape(member['email'])}\b/i)

      false
    end

    def member_name_regex(full_name)
      /\b#{Regexp.escape(full_name.to_s.strip)}\b/i
    end

    def pronoun_reference?(text:)
      text.to_s.match?(PRONOUN_REFERENCE_REGEX)
    end

    def referential_follow_up?(text:)
      pronoun_reference?(text:) || identity_question?(text:) || clarification_question?(text:)
    end

    def role_question?(text:)
      text.to_s.match?(ROLE_QUESTION_REGEX)
    end

    def recent_user_role_question?
      recent_user_messages.any? { |entry| role_question?(text: conversation_entry_content(entry)) }
    end

    def recent_user_messages
      conversation_messages.reverse_each.select do |entry|
        conversation_entry_role(entry) == 'user'
      end.first(3)
    end

    def result_data(entry)
      metadata = entry_metadata(entry)
      metadata['result_data'] || metadata[:result_data] || {}
    end

    def entry_metadata(entry)
      entry[:metadata].presence || entry['metadata'].presence || {}
    end

    def conversation_entry_role(entry)
      entry[:role].presence || entry['role'].presence
    end

    def conversation_entry_content(entry)
      entry[:content].presence || entry['content'].presence || ''
    end

    def structured_member_line(prefix:, member:)
      parts = [
        member['full_name'].presence,
        member['email'].presence,
        member['role_name'].presence,
        member['status_name'].presence
      ].compact

      "#{prefix}: #{parts.join(' | ')}"
    end

    def current_member_snapshot(member:)
      current_member = current_member_by_id(member:) || current_member_by_email(member:)
      return nil unless current_member

      member_snapshot(member: current_member)
    end

    def current_member_by_id(member:)
      return nil if member['member_id'].blank?

      workspace.members.includes(:user).find_by(id: member['member_id'])
    end

    def current_member_by_email(member:)
      return nil if member['email'].blank?

      workspace.members
        .includes(:user)
        .joins(:user)
        .find_by(users: { email: member['email'].to_s.downcase })
    end

    def member_snapshot(member:) # rubocop:disable Metrics/AbcSize
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
  end
end
