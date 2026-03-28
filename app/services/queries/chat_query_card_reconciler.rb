# frozen_string_literal: true

module Queries
  class ChatQueryCardReconciler
    def initialize(query:)
      @query = query
    end

    def call
      return unless query&.saved?

      candidate_references.find_each do |reference|
        next unless reconcile_reference!(reference:)

        sync_result_message!(reference:)
      end
    end

    private

    attr_reader :query

    def candidate_references
      ChatQueryReference.includes(:result_message)
        .where(data_source_id: query.data_source_id)
        .where(saved_query_id: [nil, query.id])
    end

    def reconcile_reference!(reference:)
      if reference.saved_query_id == query.id
        reference.sync_with_saved_query!(query:) if reference_out_of_sync?(reference:)
        return true
      end

      return false unless matching_unsaved_reference?(reference:)

      reference.attach_saved_query!(query:)
      true
    end

    def matching_unsaved_reference?(reference:)
      return false if reference.saved_query_id.present?
      return false if reference.sql.to_s.strip.blank?

      Queries::Fingerprint.build(data_source_id: query.data_source_id, sql: reference.sql) == query.query_fingerprint
    end

    def reference_out_of_sync?(reference:)
      reference.current_name != query.name ||
        Queries::Fingerprint.normalize_sql(reference.sql) != Queries::Fingerprint.normalize_sql(query.query)
    end

    def sync_result_message!(reference:)
      result_message = reference.result_message
      return unless result_message

      metadata = result_message.metadata.to_h.deep_stringify_keys
      updated_query_card = updated_query_card(metadata:)
      return if updated_query_card.blank?

      metadata['query_card'] = updated_query_card

      result_message.update!(metadata:) if metadata != result_message.metadata.to_h.deep_stringify_keys
    end

    def updated_query_card(metadata:)
      query_card = metadata['query_card'].to_h.deep_stringify_keys
      return {} if query_card.blank?

      query_card.deep_dup.merge(
        'state' => 'saved',
        'saved_query' => serialized_query_payload
      )
    end

    def serialized_query_payload
      {
        'id' => query.id,
        'name' => query.name,
        'data_source_id' => query.data_source_id,
        'data_source_name' => query.data_source.display_name,
        'sql' => query.query
      }
    end
  end
end
