# frozen_string_literal: true

module Chat
  module ThreadTitleParser
    module_function

    PATTERNS = [
      /
        \b(?:rename|retitle|change|update)\b.*\b(?:thread|chat|conversation)(?:\s+title)?\b
        .*\bto\b\s+["']?([^"']+?)["']?\s*[.!?]*\s*\z
      /ix,
      /\b(?:call|name)\b.*\b(?:this\s+)?(?:thread|chat|conversation)\b\s+["']?([^"']+?)["']?\s*[.!?]*\s*\z/i
    ].freeze
    PROPOSED_RENAME_PATTERNS = [
      /
        \b(?:rename|retitle|change|update)\b.*\b(?:thread|chat|conversation)(?:\s+title)?\b
        .*\bto\b\s+["']?([^"']+?)["']?(?:\s+now)?\s*[.!?]*\s*\z
      /ix
    ].freeze

    def parse(text:)
      source = text.to_s.strip
      return nil if source.blank?

      PATTERNS.each do |pattern|
        match = source.match(pattern)
        return cleaned(match[1]) if match
      end

      nil
    end

    def parse_proposed_title(text:)
      source = text.to_s.strip
      return nil if source.blank?

      PROPOSED_RENAME_PATTERNS.each do |pattern|
        match = source.match(pattern)
        next unless match

        parsed_title = cleaned(match[1])
        return nil if parsed_title.to_s.casecmp('match').zero?

        return parsed_title
      end

      nil
    end

    def cleaned(value)
      value.to_s.strip.sub(/[.!?]+\z/, '').presence
    end
  end
end
