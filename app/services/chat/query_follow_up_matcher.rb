# frozen_string_literal: true

module Chat
  class QueryFollowUpMatcher
    CONTEXTUAL_QUERY_FOLLOW_UP_REGEX = /
      \A\s*(?:what|how)\s+about\b|
      \A\s*what\s+if\b|
      \b(?:related\s+to\s+the\s+query\s+before|query\s+before|previous\s+query|same\s+query)\b
    /ix
    QUERY_REFINEMENT_FOLLOW_UP_REGEX = /
      \A\s*(?:can|could|would|should)\s+we\s+(?:remove|drop|exclude|include|add|filter|group|order|sort|limit|select)\b|
      \b(?:remove|drop|exclude|include|add)\b.+\b(?:column|columns|field|fields)\b|
      \b(?:without|except)\b.+\b(?:column|columns|field|fields)\b|
      \b(?:only|just)\s+(?:show|return|include|select)\b
    /ix
    NON_QUERY_TOPIC_REGEX = /\b(team|member|invite|invitation|role|workspace|settings?|dashboard)\b/i
    LETTER_VARIANT_REGEX = /\bletter\s+['"]?([[:alpha:]])['"]?\b/i

    def self.contextual_follow_up?(text:, recent_query_reference:)
      return false if recent_query_reference.to_h.blank?

      normalized_text = text.to_s.strip
      return false if normalized_text.blank?
      return false if normalized_text.match?(NON_QUERY_TOPIC_REGEX)

      normalized_text.match?(CONTEXTUAL_QUERY_FOLLOW_UP_REGEX) ||
        normalized_text.match?(QUERY_REFINEMENT_FOLLOW_UP_REGEX)
    end

    def self.letter_variant(text:)
      text.to_s.match(LETTER_VARIANT_REGEX)&.captures&.first
    end
  end
end
