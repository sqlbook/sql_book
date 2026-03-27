# frozen_string_literal: true

module Chat
  module QueryNameParser
    module_function

    PATTERNS = [
      /\b(?:rename|retitle|change)\b.*\bto\b\s+["']?([^"']+?)["']?\s*[.!?]*\s*\z/i,
      /
        \b(?:rename|retitle|change)\b.*\b(?:it|that|that\s+one|this|this\s+one|the\s+query|query)\b
        \s+["']([^"']+?)["']\s*(?:please|now)?\s*[.!?]*\s*\z
      /ix,
      /\b(?:save|call|name)\b.*\b(?:as|called|named)\b\s+["']?([^"']+?)["']?\s*[.!?]*\s*\z/i,
      /\b(?:save|call|name)\s+it\s+["']?([^"']+?)["']?\s*[.!?]*\s*\z/i
    ].freeze
    PROPOSED_RENAME_PATTERNS = [
      /\brename\s+it\s+to\b\s+["']?([^"']+?)["']?(?:\s+now)?\s*[.!?]*\s*\z/i,
      /\brenombrar(?:lo)?\s+a\b\s+["']?([^"']+?)["']?(?:\s+ahora)?\s*[.!?]*\s*\z/i
    ].freeze
    VAGUE_NAME_REGEX = /
      \A\s*(
        something|
        anything|
        whatever|
        another\s+name|
        a\s+better\s+name|
        a\s+cleaner(?:,\s*)?\s+more\s+descriptive\s+name|
        something\s+shorter(?:\s+or\s+more\s+descriptive)?|
        something\s+more\s+descriptive|
        shorter(?:\s+or\s+more\s+descriptive)?|
        more\s+descriptive(?:\s+name)?
      )\s*\z
    /ix

    def parse(text:)
      source = text.to_s.strip
      return nil if source.blank?

      PATTERNS.each do |pattern|
        match = source.match(pattern)
        return cleaned(match[1]) if match
      end

      nil
    end

    def cleaned(value)
      value.to_s.strip.sub(/[.!?]+\z/, '').presence
    end

    def parse_proposed_rename_name(text:)
      source = text.to_s.strip
      return nil if source.blank?

      PROPOSED_RENAME_PATTERNS.each do |pattern|
        match = source.match(pattern)
        next unless match

        parsed_name = cleaned(match[1])
        return nil if vague_name?(parsed_name)

        return parsed_name
      end

      nil
    end

    def vague_name?(value)
      value.to_s.strip.match?(VAGUE_NAME_REGEX)
    end
  end
end
