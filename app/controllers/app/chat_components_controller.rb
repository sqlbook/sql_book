# frozen_string_literal: true

module App
  class ChatComponentsController < ApplicationController
    before_action :require_authentication!

    def show; end
  end
end
