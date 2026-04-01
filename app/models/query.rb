# frozen_string_literal: true

class Query < ApplicationRecord
  belongs_to :data_source

  belongs_to :author,
             class_name: 'User',
             primary_key: :id

  belongs_to :last_updated_by,
             class_name: 'User',
             primary_key: :id,
             optional: true

  has_many :visualizations,
           class_name: 'QueryVisualization',
           dependent: :destroy,
           inverse_of: :query

  has_many :chat_query_references,
           dependent: :nullify,
           foreign_key: :saved_query_id,
           inverse_of: :saved_query

  before_validation :assign_query_fingerprint

  before_update :clear_query_cache!, if: :will_save_change_to_query?
  after_update :sync_chat_query_references!, if: :saved_query_reference_state_changed?
  before_destroy :unlink_chat_query_references!

  def query_result
    @query_result ||= query_service.execute
  end

  private

  def clear_query_cache!
    query_service.clear_cache!
  end

  def query_service
    @query_service ||= QueryService.new(query: self)
  end

  def saved_query_name_changed?
    saved_change_to_name? && saved?
  end

  def saved_query_reference_state_changed?
    saved? && (saved_change_to_name? || saved_change_to_query? || saved_change_to_data_source_id?)
  end

  def sync_chat_query_references!
    chat_query_references.find_each do |reference|
      reference.sync_with_saved_query!(query: self)
    end
  end

  def unlink_chat_query_references!
    chat_query_references.find_each do |reference|
      reference.unlink_saved_query!(fallback_name: name)
    end
  end

  def assign_query_fingerprint
    self.query_fingerprint = Queries::Fingerprint.build(data_source_id:, sql: query)
  end
end
