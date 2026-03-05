# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'App activity tracking', type: :request do
  let(:user) { create(:user, last_active_at: nil) }

  before { sign_in(user) }

  it 'updates last_active_at on app requests' do
    get app_workspaces_path

    expect(response).to have_http_status(:found).or have_http_status(:ok)
    expect(user.reload.last_active_at).to be_present
  end
end
