# frozen_string_literal: true

module Queries
  class GeneratedNameResponseParser
    class << self
      def parse!(body:, allow_existing_names:, existing_names:)
        parsed = JSON.parse(body)
        name = sanitize_name(extract_name(parsed))
        raise GeneratedNameService::RequestError, 'OpenAI response was empty' if name.blank?

        ensure_unique_name!(name, allow_existing_names:, existing_names:)
        name
      rescue JSON::ParserError => e
        raise GeneratedNameService::RequestError, "Invalid OpenAI response format: #{e.message}"
      end

      private

      def extract_name(parsed)
        direct = parsed.fetch('output_text', '').to_s.strip
        return direct if direct.present?

        Array(parsed['output']).flat_map do |output_item|
          Array(output_item['content']).filter_map { |content_item| content_item['text'].to_s.strip.presence }
        end.join("\n").strip
      end

      def sanitize_name(value)
        value.to_s
          .squish
          .gsub(/\A["'`]+|["'`]+\z/, '')
          .sub(/\A[-*•]\s+/, '')
          .sub(/[.!?]+\z/, '')
          .presence
      end

      def ensure_unique_name!(name, allow_existing_names:, existing_names:)
        return if allow_existing_names
        return unless existing_names.any? { |existing_name| existing_name.casecmp?(name) }

        raise GeneratedNameService::RequestError, 'OpenAI returned a duplicate query name'
      end
    end
  end
end
