# frozen_string_literal: true

module AuthenticationHelpers
  def sign_in(user)
    allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[])
      .with(:current_user_id)
      .and_return(user.id)
  end
end
