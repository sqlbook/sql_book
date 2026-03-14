# frozen_string_literal: true

module Chat
  class ConversationContextResolver # rubocop:disable Metrics/ClassLength
    PRONOUN_REFERENCE_REGEX = /\b(him|her|them|that\s+(?:person|member|user)|this\s+(?:person|member|user))\b/i
    ROLE_QUESTION_REGEX = /\b(role|admin|user|read\s*only|readonly)\b/i

    def initialize(conversation_messages:)
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
      return nil unless pronoun_reference?(text:)

      recent_invited_member || recent_removed_member
    end

    def recent_invited_member_for_role_question(text:)
      invited_member = recent_invited_member
      return nil unless invited_member
      return invited_member if pronoun_reference?(text:)

      member_matches_text?(member: invited_member, text:)
    end

    def role_question_context_active?(text:)
      role_question?(text:) || recent_user_role_question?
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

    attr_reader :conversation_messages

    def recent_result_payload(key)
      conversation_messages.reverse_each do |entry|
        payload = result_data(entry)[key] || result_data(entry)[key.to_sym]
        return payload.stringify_keys if payload.is_a?(Hash)
      end

      nil
    end

    def explicit_reference_match(text:)
      reference_text = text.to_s
      member_candidates.find do |member|
        member_matches_text?(member:, text: reference_text)
      end
    end

    def member_candidates
      [recent_invited_member, recent_removed_member, recent_updated_member]
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
  end
end
