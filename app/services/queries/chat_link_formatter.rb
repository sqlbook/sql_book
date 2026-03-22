# frozen_string_literal: true

module Queries
  class ChatLinkFormatter
    include Rails.application.routes.url_helpers

    def initialize(workspace:)
      @workspace = workspace
    end

    def markdown_link(query:, label: nil)
      resolved_label = label.presence || query_name(query)
      return resolved_label.to_s if resolved_label.to_s.strip.blank?
      return resolved_label.to_s if query_id(query).blank? || data_source_id(query).blank?

      "[#{escape_markdown_label(resolved_label)}](#{query_path_for(query:)})"
    end

    private

    attr_reader :workspace

    def query_path_for(query:)
      app_workspace_data_source_query_path(workspace, data_source_id(query), query_id(query))
    end

    def query_id(query)
      value_from(query, :id)
    end

    def data_source_id(query)
      return query.data_source_id if query.respond_to?(:data_source_id)

      nested = value_from(query, :data_source)
      return if nested.blank?

      nested[:id] || nested['id']
    end

    def query_name(query)
      value_from(query, :name)
    end

    def value_from(query, key)
      return query.public_send(key) if query.respond_to?(key)

      query[key] || query[key.to_s]
    end

    def escape_markdown_label(label)
      label.to_s.gsub(/([\\\[\]])/, '\\\\\1')
    end
  end
end
