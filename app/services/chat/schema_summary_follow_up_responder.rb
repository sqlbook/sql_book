# frozen_string_literal: true

module Chat
  class SchemaSummaryFollowUpResponder # rubocop:disable Metrics/ClassLength
    GROUP_CATEGORIES_OFFER_REGEX = /\bgroup\b.+\bcategor(?:y|ies)\b/i
    SCHEMA_SUMMARY_HEADER_REGEX = /\A(?<table>[a-z0-9_.]+)\s+includes\s+these\s+data\s+points:/i
    SCHEMA_ENTRY_REGEX = /\A(?<name>[a-z_][a-z0-9_]*)\s+—\s+(?<description>.+)\z/i
    AFFIRMATION_REGEX = /\b(yes|yeah|yep|sure|please|ok|okay|go ahead|sounds good)\b/i
    SUMMARY_REMINDER_REGEX = /\b(summari(?:se|ze|sing)|summary|group|categor(?:y|ies))\b/i
    MISSED_SUMMARY_REGEX = /\b(didn['’]t|did not|haven['’]t|have not|not yet)\b/i
    CATEGORY_ORDER = %w[identity authentication security profile other].freeze

    def initialize(message:, conversation_messages:)
      @message = message.to_s
      @conversation_messages = Array(conversation_messages).compact
    end

    def self.pending_summary(conversation_messages:)
      new(message: '', conversation_messages:).send(:pending_schema_summary)
    end

    def call
      summary = pending_schema_summary
      return nil if summary.blank?
      return nil unless follow_up_request?

      formatted_grouped_summary(summary:)
    end

    private

    attr_reader :message, :conversation_messages

    def pending_schema_summary
      conversation_messages.reverse_each do |entry|
        next unless entry_role(entry) == 'assistant'

        raw = raw_entry_content(entry)
        next if raw.blank?
        next unless raw.match?(GROUP_CATEGORIES_OFFER_REGEX)

        parsed = parse_schema_summary(raw:)
        return parsed if parsed[:entries].any?
      end

      nil
    end

    def follow_up_request?
      affirmative_follow_up? || missed_summary_follow_up?
    end

    def affirmative_follow_up?
      message.match?(AFFIRMATION_REGEX)
    end

    def missed_summary_follow_up?
      message.match?(SUMMARY_REMINDER_REGEX) && message.match?(MISSED_SUMMARY_REGEX)
    end

    def parse_schema_summary(raw:)
      lines = raw.to_s.split(/\r?\n/).map(&:strip).compact_blank

      {
        table_name: extract_table_name(lines:),
        entries: extract_entries(lines:)
      }
    end

    def formatted_grouped_summary(summary:)
      grouped = summary[:entries].group_by { |entry| category_for(entry['name']) }

      [
        "#{summary_title(summary:)} grouped into categories:",
        grouped_sections(grouped:)
      ].join("\n\n")
    end

    def category_for(field_name)
      name = field_name.to_s.downcase
      return 'authentication' if authentication_field?(name)
      return 'security' if security_field?(name)
      return 'profile' if profile_field?(name)
      return 'identity' if identity_field?(name)

      'other'
    end

    def identity_field?(name)
      %w[id email created_at updated_at tracking_id].include?(name)
    end

    def authentication_field?(name)
      name.match?(/\A(encrypted_password|reset_password_token|reset_password_sent_at|remember_created_at)\z/) ||
        name.match?(/\A(sign_in_count|current_sign_in_at|last_sign_in_at|current_sign_in_ip|last_sign_in_ip)\z/) ||
        name.match?(/\A(confirmation_token|confirmed_at|confirmation_sent_at|unconfirmed_email)\z/) ||
        name.match?(/\A(oauth_provider|oauth_uid)\z/)
    end

    def security_field?(name)
      name.match?(/\A(failed_attempts|unlock_token|locked_at|owner)\z/)
    end

    def profile_field?(name)
      name.match?(/\A(first_name|last_name|settings)\z/)
    end

    def entry_role(entry)
      entry[:role].presence || entry['role'].presence
    end

    def raw_entry_content(entry)
      entry[:content].presence || entry['content'].presence || ''
    end

    def extract_table_name(lines:)
      header = lines.find { |line| line.match?(SCHEMA_SUMMARY_HEADER_REGEX) }
      header&.match(SCHEMA_SUMMARY_HEADER_REGEX)&.[](:table)
    end

    def extract_entries(lines:)
      lines.filter_map do |line|
        entry_match = line.match(SCHEMA_ENTRY_REGEX)
        next unless entry_match

        {
          'name' => entry_match[:name],
          'description' => entry_match[:description]
        }
      end
    end

    def summary_title(summary:)
      summary[:table_name].presence || 'That table'
    end

    def grouped_sections(grouped:)
      CATEGORY_ORDER.filter_map do |category|
        entries = Array(grouped[category])
        next if entries.empty?

        format_category_section(category:, entries:)
      end.join("\n\n")
    end

    def format_category_section(category:, entries:)
      lines = entries.map { |entry| "- #{entry['name']} — #{entry['description']}" }
      "#{category.titleize}\n#{lines.join("\n")}"
    end
  end
end
