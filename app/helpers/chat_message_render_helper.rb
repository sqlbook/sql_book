# frozen_string_literal: true

module ChatMessageRenderHelper
  def render_chat_message_body(message:)
    fragments = []

    rendered_markdown = render_chat_markdown(message.content.to_s)
    fragments << rendered_markdown if rendered_markdown.present?

    rendered_query_card = render_chat_query_card(message:)
    fragments << rendered_query_card if rendered_query_card.present?

    safe_join(fragments)
  end

  def render_chat_query_card(message:)
    query_card = message.metadata.to_h.deep_stringify_keys['query_card'].to_h.deep_stringify_keys
    return if query_card.blank?

    render partial: 'app/workspaces/chat/query_card', formats: [:html], locals: { message:, query_card: }
  end
end
