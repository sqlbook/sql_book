# frozen_string_literal: true

class HomeController < ApplicationController
  before_action :redirect_authenticated_users_to_app!

  def index; end
end
