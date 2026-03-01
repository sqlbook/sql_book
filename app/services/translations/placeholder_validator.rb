# frozen_string_literal: true

module Translations
  class PlaceholderValidator
    PLACEHOLDER_PATTERN = /%\{([a-zA-Z0-9_]+)\}/

    class << self
      def placeholders(text)
        text.to_s.scan(PLACEHOLDER_PATTERN).flatten.sort
      end

      def valid_placeholders?(source:, candidate:)
        placeholders(source) == placeholders(candidate)
      end
    end
  end
end
