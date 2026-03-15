# frozen_string_literal: true

module Chat
  class RoleParser
    READ_ONLY_ROLE_REGEX = /
      \A(?:i\s+(?:think|guess|mean)\s+)?(?:read[-\s]?only|readonly)\.?\z|
      \b(?:as|role|make|set|give)\b.*\b(?:read[-\s]?only|readonly)\b
    /ix

    class << self
      def parse(text:)
        lowered = text.to_s.downcase.strip
        return Member::Roles::ADMIN if admin_role?(lowered)
        return Member::Roles::READ_ONLY if lowered.match?(READ_ONLY_ROLE_REGEX)
        return Member::Roles::USER if user_role?(lowered)

        nil
      end

      private

      def admin_role?(lowered)
        lowered.match?(admin_role_regex)
      end

      def user_role?(lowered)
        lowered.match?(
          /\A(?:i\s+(?:think|guess|mean)\s+)?user\.?\z|\b(?:as|role|make|set|give)\b.*\buser\b/i
        )
      end

      def admin_role_regex
        /
          \A(?:i\s+(?:think|guess|mean)\s+)?(?:admin|administrator)\.?\z|
          \b(?:as|role|make|set|give)\b.*\b(?:admin|administrator)\b
        /ix
      end
    end
  end
end
