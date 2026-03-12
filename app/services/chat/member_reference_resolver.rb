# frozen_string_literal: true

module Chat
  class MemberReferenceResolver
    EMAIL_REGEX = /[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}/i

    def initialize(workspace:)
      @workspace = workspace
    end

    def resolve(payload: nil, text: nil)
      payload_hash = payload.to_h.stringify_keys

      resolve_from_member_id(payload_hash) ||
        resolve_from_email(payload_hash['email']) ||
        resolve_from_full_name(payload_hash['full_name']) ||
        resolve_from_name_parts(payload_hash) ||
        resolve_from_text(text)
    end

    def reference_payload(payload: nil, text: nil)
      member = resolve(payload:, text:)
      return {} unless member

      {
        'member_id' => member.id,
        'email' => member.user&.email.to_s.presence,
        'full_name' => member.user&.full_name.to_s.presence
      }.compact
    end

    private

    attr_reader :workspace

    def resolve_from_member_id(payload)
      member_id = payload['member_id'].to_i if payload['member_id'].present?
      return nil unless member_id

      workspace.members.find_by(id: member_id)
    end

    def resolve_from_email(raw_email)
      email = normalized_email(raw_email)
      return nil if email.blank?

      workspace.members.joins(:user).find_by(users: { email: })
    end

    def resolve_from_full_name(raw_full_name)
      full_name = normalized_name(raw_full_name)
      return nil if full_name.blank?

      exact_name_matches(full_name).one? ? exact_name_matches(full_name).first : nil
    end

    def resolve_from_name_parts(payload)
      first_name = normalized_name(payload['first_name'])
      last_name = normalized_name(payload['last_name'])
      return nil if first_name.blank? || last_name.blank?

      resolve_from_full_name("#{first_name} #{last_name}")
    end

    def resolve_from_text(raw_text)
      text = raw_text.to_s
      return nil if text.blank?

      resolve_from_email(text[EMAIL_REGEX]) || resolve_from_member_name_mentions(text)
    end

    def resolve_from_member_name_mentions(text)
      matches = workspace_members.select do |member|
        full_name = normalized_name(member.user&.full_name)
        next false if full_name.blank?

        text.match?(member_name_regex(full_name))
      end

      matches.one? ? matches.first : nil
    end

    def member_name_regex(full_name)
      /\b#{Regexp.escape(full_name)}\b/i
    end

    def exact_name_matches(full_name)
      workspace_members.select do |member|
        normalized_name(member.user&.full_name) == full_name
      end
    end

    def workspace_members
      @workspace_members ||= workspace.members.includes(:user).to_a
    end

    def normalized_email(value)
      value.to_s.strip.downcase.presence
    end

    def normalized_name(value)
      value.to_s.strip.gsub(/\s+/, ' ').presence
    end
  end
end
