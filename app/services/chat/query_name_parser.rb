# frozen_string_literal: true

module Chat
  module QueryNameParser
    module_function

    PATTERNS = [
      /\b(?:save|call|name)\b.*\b(?:as|called|named)\b\s+["']?([^"']+?)["']?\s*\z/i,
      /\b(?:save|call|name)\s+it\s+["']?([^"']+?)["']?\s*\z/i
    ].freeze

    def parse(text:)
      source = text.to_s.strip
      return nil if source.blank?

      quoted = source.match(/["']([^"']+)["']/)
      return cleaned(quoted[1]) if quoted && source.match?(/\b(save|call|name)\b/i)

      PATTERNS.each do |pattern|
        match = source.match(pattern)
        return cleaned(match[1]) if match
      end

      nil
    end

    def cleaned(value)
      value.to_s.strip.sub(/[.!?]+\z/, '').presence
    end
  end
end
