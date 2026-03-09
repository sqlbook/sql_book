# frozen_string_literal: true

module App
  module Workspaces
    class ChatThreadsController < ApplicationController
      before_action :require_authentication!
      before_action :set_workspace
      before_action :set_chat_thread, only: %i[update destroy]

      def index
        render json: {
          threads: chat_threads.map { |chat_thread| serialize_thread(chat_thread:) }
        }
      end

      def create
        chat_thread = workspace.chat_threads.create!(created_by: current_user)

        render json: {
          status: 'ok',
          thread: serialize_thread(chat_thread:)
        }, status: :created
      end

      def update
        title = params[:title].to_s.strip
        if title.blank?
          return render json: {
            status: 'validation_error',
            message: I18n.t('app.workspaces.chat.errors.thread_title_required')
          }, status: :unprocessable_entity
        end

        chat_thread.update!(title:)

        render json: {
          status: 'ok',
          thread: serialize_thread(chat_thread:)
        }
      end

      def destroy
        chat_thread.update!(archived_at: Time.current)

        render json: {
          status: 'ok',
          redirect_path: next_redirect_path
        }
      end

      private

      attr_reader :chat_thread

      def workspace
        @workspace ||= find_workspace_for_current_user!(param_key: :workspace_id)
      end

      def set_workspace
        workspace
      end

      def set_chat_thread
        @chat_thread = chat_threads.find(params[:id])
      end

      def chat_threads
        @chat_threads ||= workspace.chat_threads
          .active
          .for_user(current_user)
          .with_messages
          .order(updated_at: :desc, id: :desc)
      end

      def next_redirect_path
        next_thread = chat_threads.where.not(id: chat_thread.id).first
        return app_workspace_path(workspace, thread_id: next_thread.id) if next_thread

        app_workspace_path(workspace, new_chat: 1)
      end

      def serialize_thread(chat_thread:)
        {
          id: chat_thread.id,
          title: chat_thread.title.to_s,
          updated_at: chat_thread.updated_at.iso8601
        }
      end
    end
  end
end
