# frozen_string_literal: true

module Api
  module V1
    class ChatThreadsController < Api::BaseController
      def update
        execute_tool(
          action_type: 'thread.rename',
          payload: {
            'thread_id' => params[:id].to_i,
            'title' => params[:title].to_s.presence
          }.compact
        )
      end
    end
  end
end
