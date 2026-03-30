# frozen_string_literal: true

module Tooling
  class WorkspaceChatThreadHandlers
    def initialize(workspace:, actor:)
      @workspace = workspace
      @actor = actor
    end

    def rename(arguments:)
      thread = target_thread(arguments:)
      unless thread
        return validation_error(code: 'thread.not_found', fallback_message: 'I could not find that chat thread.')
      end

      title = arguments['title'].to_s.strip
      if title.blank?
        return validation_error(code: 'thread.title_required', fallback_message: 'Please enter a chat name.')
      end

      thread.update!(title:)

      Result.new(
        status: 'executed',
        code: 'thread.renamed',
        data: { 'thread' => thread_payload(thread:) },
        fallback_message: "Renamed this chat to #{thread.title}."
      )
    end

    private

    attr_reader :workspace, :actor

    def target_thread(arguments:)
      workspace.chat_threads.active.for_user(actor).find_by(id: arguments['thread_id'])
    end

    def thread_payload(thread:)
      {
        'id' => thread.id,
        'title' => thread.title.to_s,
        'updated_at' => thread.updated_at.iso8601
      }
    end

    def validation_error(code:, fallback_message:)
      Result.new(
        status: 'validation_error',
        code:,
        data: {},
        fallback_message:
      )
    end
  end
end
