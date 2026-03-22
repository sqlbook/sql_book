# frozen_string_literal: true

require 'digest'

module Queries
  module Fingerprint
    module_function

    def build(data_source_id:, sql:)
      return nil if data_source_id.blank?

      normalized_sql = normalize_sql(sql)
      return nil if normalized_sql.blank?

      Digest::SHA256.hexdigest([data_source_id, normalized_sql].join(':'))
    end

    def normalize_sql(sql)
      value = sql.to_s.strip
      return nil if value.blank?

      value
        .sub(/;\s*\z/, '')
        .gsub(/\s+/, ' ')
        .strip
        .presence
    end
  end
end
