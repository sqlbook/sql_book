# frozen_string_literal: true

module Chat
  class RoleParser
    ROLE_VALUE_PATTERN = 'admin|administrator|user|read[-\\s]?only|readonly'

    EXPLICIT_TARGET_ROLE_REGEXES = [
      /\b(?:promote|demote|change|update|switch)\b.*?\bto\b\s+
        (?:a\s+|an\s+)?(?<role>#{ROLE_VALUE_PATTERN})\b/ix,
      /\b(?:make|set|give)\b.*?\b(?<role>#{ROLE_VALUE_PATTERN})\b(?:\s+role)?\b/ix,
      /\b(?<role>#{ROLE_VALUE_PATTERN})\b(?:\s+role)?\s+\b(?:instead of|rather than)\b/ix
    ].freeze

    ROLE_INLINE_REFERENCE = /
      (?=\s+(?:called|named|with|whose|who|at|for)\b)
    /ix

    READ_ONLY_ROLE_REGEX = /
      \A(?:i\s+(?:think|guess|mean)\s+)?(?:read[-\s]?only|readonly)\.?\z|
      \b(?:as|role|make|set|give)\b.*\b(?:read[-\s]?only|readonly)\b|
      \b(?:can|could|should|would)\s+be\s+(?:a\s+|an\s+)?(?:read[-\s]?only|readonly)\b|
      \b(?:promote|demote|change|update|switch)\b.*\bto\b.*\b(?:read[-\s]?only|readonly)\b|
      \b(?:read[-\s]?only|readonly)\b#{ROLE_INLINE_REFERENCE}
    /ix

    class << self
      def parse(text:)
        lowered = text.to_s.downcase.strip
        explicit_target = explicit_target_role(lowered)
        return explicit_target if explicit_target

        return Member::Roles::ADMIN if admin_role?(lowered)
        return Member::Roles::READ_ONLY if lowered.match?(READ_ONLY_ROLE_REGEX)
        return Member::Roles::USER if user_role?(lowered)

        nil
      end

      private

      def explicit_target_role(lowered)
        EXPLICIT_TARGET_ROLE_REGEXES.each do |regex|
          match = lowered.match(regex)
          next unless match

          parsed = role_value_for(role_text: match[:role])
          return parsed if parsed
        end

        nil
      end

      def role_value_for(role_text:)
        normalized = role_text.to_s.strip
        return Member::Roles::ADMIN if normalized.match?(/\A(admin|administrator)\z/i)
        return Member::Roles::READ_ONLY if normalized.match?(/\A(read[-\s]?only|readonly)\z/i)
        return Member::Roles::USER if normalized.match?(/\Auser\z/i)

        nil
      end

      def admin_role?(lowered)
        lowered.match?(admin_role_regex)
      end

      def user_role?(lowered)
        lowered.match?(
          /
            \A(?:i\s+(?:think|guess|mean)\s+)?user\.?\z|
            \b(?:as|role|make|set|give)\b.*\buser\b|
            \b(?:can|could|should|would)\s+be\s+(?:a\s+|an\s+)?user\b|
            \b(?:promote|demote|change|update|switch)\b.*\bto\b.*\buser\b|
            \buser\b#{ROLE_INLINE_REFERENCE}
          /ix
        )
      end

      def admin_role_regex
        /
          \A(?:i\s+(?:think|guess|mean)\s+)?(?:admin|administrator)\.?\z|
          \b(?:as|role|make|set|give)\b.*\b(?:admin|administrator)\b|
          \b(?:can|could|should|would)\s+be\s+(?:a\s+|an\s+)?(?:admin|administrator)\b|
          \b(?:promote|demote|change|update|switch)\b.*\bto\b.*\b(?:admin|administrator)\b|
          \b(?:admin|administrator)\b#{ROLE_INLINE_REFERENCE}
        /ix
      end
    end
  end
end
