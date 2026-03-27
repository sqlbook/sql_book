# frozen_string_literal: true

module Chat
  class PromptContextFormatter
    def initialize(context_snapshot:, conversation_messages:, transcript_limit:, transcript_character_limit:)
      @context_snapshot = context_snapshot
      @conversation_messages = Array(conversation_messages).compact
      @transcript_limit = transcript_limit
      @transcript_character_limit = transcript_character_limit
    end

    def call
      parts = []
      parts.concat(structured_section_blocks)
      parts << recent_conversation_block if transcript_lines.any?
      return 'Recent conversation: none' if parts.empty?

      parts.join("\n")
    end

    private

    attr_reader :context_snapshot, :conversation_messages, :transcript_limit, :transcript_character_limit

    def structured_section_blocks
      sections = typed_context_snapshot? ? Array(context_snapshot.structured_context_sections) : fallback_sections

      sections.filter_map { |section| rendered_section(section:) }
    end

    def fallback_sections
      lines = Array(context_snapshot&.structured_context_lines).compact_blank
      return [] if lines.empty?

      [{ title: 'Recent structured context', lines: }]
    end

    def recent_conversation_block
      "Recent conversation:\n#{transcript_lines.join("\n")}"
    end

    def transcript_lines
      conversation_messages.last(transcript_limit).filter_map do |entry|
        rendered_transcript_line(entry:)
      end
    end

    def typed_context_snapshot?
      context_snapshot.is_a?(Chat::ContextSnapshot)
    end

    def rendered_section(section:)
      title = section_title(section:)
      lines = section_lines(section:)
      return nil if title.blank? || lines.empty?

      "#{title}:\n#{lines.join("\n")}"
    end

    def section_title(section:)
      section[:title].presence || section['title'].presence
    end

    def section_lines(section:)
      Array(section[:lines].presence || section['lines'].presence).compact_blank
    end

    def rendered_transcript_line(entry:)
      role = entry[:role].presence || entry['role'].presence
      content = entry[:content].presence || entry['content'].presence || ''
      cleaned = content.to_s.gsub(/\s+/, ' ').strip[0, transcript_character_limit]
      return nil if role.blank? || cleaned.blank?

      "#{role}: #{cleaned}"
    end
  end
end
