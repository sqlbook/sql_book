# frozen_string_literal: true

require 'rails_helper'

feature 'Sign up' do
  scenario 'with an email that is not registered and the correct OTP code' do
    visit auth_signup_index_path

    fill_in 'First name', with: 'Robby'
    fill_in 'Last name', with: 'Kreiger'
    fill_in 'Email', with: 'robby.kreiger@thedoors.com'

    check 'I have read and accept the Terms Of Service.'

    click_button '[Continue]'

    expect(page).to have_content("We've sent you a temporary sign-up code")

    otp = OneTimePassword.find_by(email: 'robby.kreiger@thedoors.com')

    fill_in id: 'one_time_password_1', with: otp.token[0]
    fill_in id: 'one_time_password_2', with: otp.token[1]
    fill_in id: 'one_time_password_3', with: otp.token[2]
    fill_in id: 'one_time_password_4', with: otp.token[3]
    fill_in id: 'one_time_password_5', with: otp.token[4]
    fill_in id: 'one_time_password_6', with: otp.token[5]

    click_button '[Sign Up]'

    expect(page).to have_content('Welcome to sqlbook')
  end

  scenario 'with an email that is not registered and an incorrect OTP code' do
    visit auth_signup_index_path

    fill_in 'First name', with: 'Robby'
    fill_in 'Last name', with: 'Kreiger'
    fill_in 'Email', with: 'robby.kreiger@thedoors.com'

    check 'I have read and accept the Terms Of Service.'

    click_button '[Continue]'

    expect(page).to have_content("We've sent you a temporary sign-up code")

    fill_in id: 'one_time_password_1', with: '9'
    fill_in id: 'one_time_password_2', with: '9'
    fill_in id: 'one_time_password_3', with: '9'
    fill_in id: 'one_time_password_4', with: '9'
    fill_in id: 'one_time_password_5', with: '9'
    fill_in id: 'one_time_password_6', with: '9'

    click_button '[Sign Up]'

    expect(page).to have_content('Invalid sign-up code. Please try again or click here for a replacement code.')
  end

  scenario 'with an email address that is registered' do
    user = create(:user)

    visit auth_signup_index_path

    fill_in 'First name', with: user.first_name
    fill_in 'Last name', with: user.last_name
    fill_in 'Email', with: user.email

    check 'I have read and accept the Terms Of Service.'

    click_button '[Continue]'

    expect(page).to have_content('An account with this email already exists')
  end
end
