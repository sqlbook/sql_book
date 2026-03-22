# frozen_string_literal: true

class ChatQueryReference < ApplicationRecord # rubocop:disable Metrics/ClassLength
  belongs_to :chat_thread,
             inverse_of: :chat_query_references

  belongs_to :source_message,
             class_name: 'ChatMessage',
             optional: true,
             inverse_of: :source_query_references

  belongs_to :result_message,
             class_name: 'ChatMessage',
             optional: true,
             inverse_of: :result_query_references

  belongs_to :data_source,
             optional: true

  belongs_to :saved_query,
             class_name: 'Query',
             optional: true,
             inverse_of: :chat_query_references

  belongs_to :refined_from_reference,
             class_name: 'ChatQueryReference',
             optional: true

  validates :current_name, length: { maximum: 255 }, allow_blank: true

  before_validation :normalize_array_attributes

  scope :recent_first, -> { order(updated_at: :desc, id: :desc) }

  # rubocop:disable Metrics/AbcSize
  def attach_saved_query!(query:, source_message: nil, result_message: nil)
    previous_name = current_name.presence

    self.source_message ||= source_message
    self.result_message ||= result_message
    self.saved_query = query
    self.data_source ||= query.data_source
    self.sql ||= query.query
    self.current_name = query.name
    append_alias(previous_name)
    append_alias(query.name_was) if query.respond_to?(:name_was)
    save!
  end
  # rubocop:enable Metrics/AbcSize

  def sync_with_saved_query!(query:)
    previous_name = current_name.presence

    self.saved_query = query
    self.data_source = query.data_source
    self.sql = query.query
    self.current_name = query.name
    append_alias(previous_name)
    append_alias(query.name_before_last_save || query.name_in_database || query.name)
    save!
  end

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def rename_to!(new_name:, result_message: nil)
    normalized_name = new_name.to_s.strip
    return if normalized_name.blank?

    self.current_name = normalized_name
    append_alias(current_name_before_last_save || current_name_in_database || current_name)
    append_alias(saved_query&.name_before_last_save || saved_query&.name_in_database || saved_query&.name)
    self.result_message ||= result_message
    save!
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def unlink_saved_query!(fallback_name: nil, result_message: nil)
    preserved_name = fallback_name.to_s.strip.presence || current_name.presence || saved_query&.name.to_s.presence
    self.current_name = preserved_name if preserved_name.present?
    append_alias(current_name_before_last_save || current_name_in_database || current_name)
    append_alias(saved_query&.name_before_last_save || saved_query&.name_in_database || saved_query&.name)
    self.saved_query = nil
    self.result_message ||= result_message
    save!
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  # rubocop:disable Metrics/AbcSize
  def serialized_payload
    {
      'id' => id,
      'source_message_id' => source_message_id,
      'result_message_id' => result_message_id,
      'data_source_id' => data_source_id,
      'data_source_name' => data_source&.display_name.to_s.presence,
      'original_question' => original_question.to_s,
      'sql' => sql.to_s,
      'current_name' => current_name.to_s,
      'name_aliases' => Array(name_aliases),
      'row_count' => row_count,
      'columns' => Array(columns),
      'saved_query_id' => saved_query_id,
      'saved_query_name' => current_name.to_s.presence || saved_query&.name.to_s.presence,
      'refined_from_reference_id' => refined_from_reference_id,
      'refined_saved_query_id' => refined_saved_query&.id,
      'refined_saved_query_name' => refined_saved_query&.name.to_s.presence,
      'updated_at' => updated_at&.iso8601
    }.compact
  end
  # rubocop:enable Metrics/AbcSize

  private

  def append_alias(candidate)
    value = candidate.to_s.strip
    return if value.blank?
    return if normalized_name(value) == normalized_name(current_name)

    self.name_aliases = Array(name_aliases).map(&:to_s).push(value).uniq do |name|
      normalized_name(name)
    end
  end

  def normalize_array_attributes
    self.name_aliases = Array(name_aliases).map(&:to_s).map(&:strip).compact_blank
    self.columns = Array(columns).map(&:to_s).map(&:strip).compact_blank
  end

  def normalized_name(value)
    value.to_s.strip.gsub(/\s+/, ' ').downcase
  end

  def refined_saved_query
    refined_from_reference&.saved_query
  end
end
