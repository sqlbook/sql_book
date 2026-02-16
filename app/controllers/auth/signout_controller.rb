# frozen_string_literal: true

module Auth
  class SignoutController < ApplicationController
    def index
      reset_session
      redirect_to root_path
    end
  end
end
