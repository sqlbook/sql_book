# frozen_string_literal: true

module Queries
  class ChatSourceResolver
    def initialize(query:, viewer:, workspace:)
      @query = query
      @viewer = viewer
      @workspace = workspace
    end

    # rubocop:disable Metrics/AbcSize
    def call
      reference = accessible_reference
      return unless reference

      message_id = reference.result_message_id || reference.source_message_id

      {
        'thread_id' => reference.chat_thread_id,
        'message_id' => message_id,
        'path' => thread_path(thread_id: reference.chat_thread_id, message_id:),
        'thread_title' => reference.chat_thread.title.to_s.presence,
        'message_preview' => reference.original_question.to_s.presence || reference.current_name.to_s.presence
      }.compact
    end
    # rubocop:enable Metrics/AbcSize

    private

    attr_reader :query, :viewer, :workspace

    def accessible_reference
      query.chat_query_references
        .includes(:chat_thread)
        .order(:created_at, :id)
        .detect { |reference| thread_accessible?(reference.chat_thread) }
    end

    def thread_accessible?(chat_thread)
      chat_thread.present? &&
        chat_thread.workspace_id == workspace.id &&
        chat_thread.created_by_id == viewer.id
    end

    def thread_path(thread_id:, message_id:)
      helpers.app_workspace_path(
        workspace,
        thread_id:,
        anchor: message_id.present? ? chat_message_anchor(message_id) : nil
      )
    end

    def chat_message_anchor(message_id)
      "chat-message-#{message_id}"
    end

    def helpers
      Rails.application.routes.url_helpers
    end
  end
end
