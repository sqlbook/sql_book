# frozen_string_literal: true

module Queries
  class NameReviewResponseParser
    Result = Struct.new(:status, :suggested_name, :reason, keyword_init: true)
    VALID_STATUSES = %w[aligned stale uncertain].freeze

    class << self
      def parse!(body:) # rubocop:disable Metrics/AbcSize
        parsed = JSON.parse(body)
        payload = extract_payload(parsed)
        status = payload['status'].to_s.strip
        raise GeneratedNameService::RequestError, 'OpenAI response was empty' if status.blank?
        unless VALID_STATUSES.include?(status)
          raise GeneratedNameService::RequestError, 'OpenAI returned an invalid review status'
        end

        Result.new(
          status:,
          suggested_name: sanitize_name(payload['suggested_name']),
          reason: payload['reason'].to_s.squish.presence
        )
      rescue JSON::ParserError => e
        raise GeneratedNameService::RequestError, "Invalid OpenAI response format: #{e.message}"
      end

      private

      def extract_payload(parsed) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
        return parsed if parsed.is_a?(Hash) && parsed['status'].present?

        output_text = parsed.fetch('output_text', '').to_s.strip
        return JSON.parse(output_text) if output_text.present?

        rendered = Array(parsed['output']).flat_map do |output_item|
          Array(output_item['content']).filter_map do |content_item|
            raw_text = content_item['text']
            value = raw_text.is_a?(Hash) ? raw_text['value'] : raw_text
            value.to_s.strip.presence
          end
        end.join("\n").strip
        return JSON.parse(rendered) if rendered.present?

        {}
      end

      def sanitize_name(value)
        value.to_s
          .squish
          .gsub(/\A["'`]+|["'`]+\z/, '')
          .sub(/\A[-*•]\s+/, '')
          .sub(/[.!?]+\z/, '')
          .presence
      end
    end
  end
end
