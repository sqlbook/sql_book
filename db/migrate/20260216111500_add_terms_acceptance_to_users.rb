# frozen_string_literal: true

class AddTermsAcceptanceToUsers < ActiveRecord::Migration[7.1]
  def change
    change_table :users, bulk: true do |table|
      table.datetime :terms_accepted_at
      table.string :terms_version
    end
  end
end
