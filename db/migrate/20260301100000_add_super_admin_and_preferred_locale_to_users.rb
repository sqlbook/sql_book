# frozen_string_literal: true

class AddSuperAdminAndPreferredLocaleToUsers < ActiveRecord::Migration[8.0]
  def change
    change_table :users, bulk: true do |table|
      table.boolean :super_admin, default: false, null: false
      table.string :preferred_locale
    end
  end
end
