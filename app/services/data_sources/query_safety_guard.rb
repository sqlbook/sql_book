# frozen_string_literal: true

module DataSources
  module QuerySafetyGuard
    module_function

    DISALLOWED_KEYWORDS = %w[
      insert
      update
      delete
      merge
      drop
      alter
      create
      truncate
      grant
      revoke
      comment
      copy
      call
      do
      vacuum
      analyze
      refresh
      reindex
      attach
      detach
    ].freeze

    def validate!(sql:)
      normalized_sql = normalized(sql)

      raise_query_error('blank_query') if normalized_sql.blank?
      raise_query_error('multiple_statements') if multiple_statements?(normalized_sql)
      raise_query_error('read_only_only') unless normalized_sql.match?(/\A(select|with)\b/i)
      raise_query_error('blocked_keyword') if blocked_keyword?(normalized_sql)
    end

    def limit_sql(sql:, max_rows:)
      stripped_sql = sql.to_s.strip.sub(/;+\z/, '')
      "SELECT * FROM (#{stripped_sql}) AS sqlbook_query LIMIT #{max_rows.to_i}"
    end

    def normalized(sql)
      sql.to_s
        .gsub(%r{/\*.*?\*/}m, ' ')
        .lines
        .map { |line| line.sub(/--.*$/, '') }
        .join(' ')
        .squish
    end

    def multiple_statements?(normalized_sql)
      normalized_sql.sub(/;+\z/, '').include?(';')
    end

    def blocked_keyword?(normalized_sql)
      DISALLOWED_KEYWORDS.any? { |keyword| normalized_sql.match?(/\b#{Regexp.escape(keyword)}\b/i) }
    end

    def raise_query_error(key)
      raise Connectors::BaseConnector::QueryError.new(
        I18n.t("app.workspaces.data_sources.query_guard.#{key}"),
        code: key
      )
    end
  end
end
