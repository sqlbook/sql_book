# frozen_string_literal: true

require 'digest'

class AddQueryFingerprintsAndRefinementLinks < ActiveRecord::Migration[8.0]
  class MigrationQuery < ApplicationRecord
    self.table_name = 'queries'
  end

  class DuplicateSavedQueryError < StandardError; end

  def up
    add_column :queries, :query_fingerprint, :string
    add_reference :chat_query_references,
                  :refined_from_reference,
                  foreign_key: { to_table: :chat_query_references }

    backfill_query_fingerprints!
    fail_if_duplicate_saved_queries!

    add_index :queries,
              %i[data_source_id query_fingerprint],
              unique: true,
              where: 'saved = TRUE AND query_fingerprint IS NOT NULL',
              name: 'index_queries_on_data_source_and_query_fingerprint_saved'
  end

  def down
    remove_index :queries, name: 'index_queries_on_data_source_and_query_fingerprint_saved'
    remove_reference :chat_query_references, :refined_from_reference, foreign_key: { to_table: :chat_query_references }
    remove_column :queries, :query_fingerprint
  end

  private

  def backfill_query_fingerprints!
    say_with_time 'Backfilling query fingerprints' do
      MigrationQuery.find_each do |query|
        fingerprint = fingerprint_for(data_source_id: query.data_source_id, sql: query.query)
        query.update!(query_fingerprint: fingerprint)
      end
    end
  end

  def fail_if_duplicate_saved_queries!
    duplicates = MigrationQuery
      .where(saved: true)
      .where.not(query_fingerprint: nil)
      .group(:data_source_id, :query_fingerprint)
      .having('COUNT(*) > 1')
      .count

    return if duplicates.empty?

    first_duplicate = duplicates.keys.first
    raise DuplicateSavedQueryError,
          "Duplicate saved queries detected for data_source_id=#{first_duplicate[0]} fingerprint=#{first_duplicate[1]}"
  end

  def fingerprint_for(data_source_id:, sql:)
    return nil if data_source_id.blank?

    normalized_sql = normalize_sql(sql)
    return nil if normalized_sql.blank?

    Digest::SHA256.hexdigest([data_source_id, normalized_sql].join(':'))
  end

  def normalize_sql(sql)
    value = sql.to_s.strip
    return nil if value.blank?

    value.sub(/;\s*\z/, '').gsub(/\s+/, ' ').strip.presence
  end
end
