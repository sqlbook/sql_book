# frozen_string_literal: true

require 'rails_helper'

feature 'Log in' do
  scenario 'with an email that is registered and the correct OTP code' do
    user = create(:user)

    visit auth_login_index_path

    fill_in 'Email', with: user.email

    click_button '[Log In]'

    expect(page).to have_content("We've sent you a temporary log-in code to")

    otp = OneTimePassword.find_by(email: user.email)

    fill_in id: 'one_time_password_1', with: otp.token[0]
    fill_in id: 'one_time_password_2', with: otp.token[1]
    fill_in id: 'one_time_password_3', with: otp.token[2]
    fill_in id: 'one_time_password_4', with: otp.token[3]
    fill_in id: 'one_time_password_5', with: otp.token[4]
    fill_in id: 'one_time_password_6', with: otp.token[5]

    click_button '[Log In]'

    expect(page).to have_content('Welcome to sqlbook')
  end

  scenario 'with an email that is registered and an incorrect OTP code' do
    user = create(:user)

    visit auth_login_index_path

    fill_in 'Email', with: user.email

    click_button '[Log In]'

    expect(page).to have_content("We've sent you a temporary log-in code to")

    fill_in id: 'one_time_password_1', with: '7'
    fill_in id: 'one_time_password_2', with: '7'
    fill_in id: 'one_time_password_3', with: '7'
    fill_in id: 'one_time_password_4', with: '7'
    fill_in id: 'one_time_password_5', with: '7'
    fill_in id: 'one_time_password_6', with: '7'

    click_button '[Log In]'

    expect(page).to have_content('Invalid log-in code. Please try again or click here for a replacement code.')
  end

  scenario 'with an email that is not registered' do
    visit auth_login_index_path

    fill_in 'Email', with: 'sdfsdfsdfd@gmail.com'

    click_button '[Log In]'

    expect(page).to have_content('An account with this email does not exist')
  end
end
