# frozen_string_literal: true

module Visualizations
  class ThemeFormBuilder
    FIELD_MAP = {
      colors_csv: [%w[color]],
      background_color: [%w[backgroundColor]],
      text_color: [%w[textStyle color]],
      title_color: [%w[title textStyle color]],
      subtitle_color: [%w[title subtextStyle color]],
      legend_text_color: [%w[legend textStyle color]],
      axis_line_color: [
        %w[categoryAxis axisLine lineStyle color],
        %w[valueAxis axisLine lineStyle color]
      ],
      axis_label_color: [
        %w[categoryAxis axisLabel color],
        %w[valueAxis axisLabel color]
      ],
      split_line_color: [
        %w[categoryAxis splitLine lineStyle color],
        %w[valueAxis splitLine lineStyle color]
      ],
      tooltip_background_color: [%w[tooltip backgroundColor]],
      tooltip_text_color: [%w[tooltip textStyle color]]
    }.freeze

    class << self
      def editor_attributes(theme_json:)
        theme_json = theme_json.to_h.deep_stringify_keys

        FIELD_MAP.each_with_object(raw_json: JSON.pretty_generate(theme_json)) do |(field, paths), memo|
          memo[field] = if field == :colors_csv
                          Array(theme_json['color']).join(', ')
                        else
                          dig_first_value(theme_json, paths)
                        end
        end
      end

      def build(theme_json:, editor_params:, raw_json:)
        parsed_json = parse_json(raw_json)
        return parsed_json if parsed_json

        apply_editor_params(theme_json:, editor_params:)
      end

      private

      def parse_json(raw_json)
        value = raw_json.to_s.strip
        return nil if value.blank?

        JSON.parse(value)
      rescue JSON::ParserError
        nil
      end

      def apply_editor_params(theme_json:, editor_params:)
        payload = theme_json.to_h.deep_stringify_keys

        FIELD_MAP.each do |field, path|
          value = editor_params[field].to_s.strip
          next if value.blank?

          normalized_value = field == :colors_csv ? value.split(',').map(&:strip).compact_blank : value
          Array(path).each do |nested_path|
            payload = write_value(payload:, path: nested_path.dup, value: normalized_value)
          end
        end

        payload
      end

      def write_value(payload:, path:, value:)
        leaf = path.pop
        container = path.reduce(payload) do |memo, key|
          memo[key] ||= {}
          memo[key]
        end

        container[leaf] = value
        payload
      end

      def dig_first_value(payload, paths)
        Array(paths).map { |path| payload.dig(*path) }.compact_blank.first
      end
    end
  end
end
