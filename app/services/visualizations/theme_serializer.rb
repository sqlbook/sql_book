# frozen_string_literal: true

module Visualizations
  class ThemeSerializer
    class << self
      def call(theme:)
        {
          'id' => theme.id,
          'reference' => theme.reference_key,
          'name' => theme.name,
          'default' => theme.default?,
          'read_only' => theme.read_only?,
          'system_theme' => theme.system_theme?,
          'theme_json_dark' => theme.theme_json_dark,
          'theme_json_light' => theme.theme_json_light
        }
      end
    end
  end
end
