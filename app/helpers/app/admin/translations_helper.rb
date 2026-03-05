# frozen_string_literal: true

module App
  module Admin
    module TranslationsHelper
      def translation_value_for(translation_key:, locale:, suggestions:)
        suggestion = suggestions.dig(translation_key.id.to_s, locale)
        return suggestion if suggestion.present?

        translation_key.translation_values.find { |value| value.locale == locale }&.value.to_s
      end

      def persisted_translation_value_for(translation_key:, locale:)
        translation_key.translation_values.find { |value| value.locale == locale }&.value.to_s
      end

      def used_in_entries(translation_key:)
        Array(translation_key.used_in).map do |entry|
          {
            label: (entry['label'] || entry[:label]).to_s,
            path: (entry['path'] || entry[:path]).to_s
          }
        end
      end

      def used_in_path_linkable?(path:)
        path.present? && path.start_with?('/')
      end

      def resolve_used_in_path(path:)
        return '' if path.blank?
        return path unless path.include?(':workspace_id')

        workspace_id = current_used_in_workspace_id
        return '' if workspace_id.blank?

        path.gsub(':workspace_id', workspace_id.to_s)
      end

      private

      def current_used_in_workspace_id
        user = controller.send(:current_user) if controller.respond_to?(:current_user, true)
        return nil unless user

        user.workspaces.order(:id).limit(1).pick(:id)
      end
    end
  end
end
