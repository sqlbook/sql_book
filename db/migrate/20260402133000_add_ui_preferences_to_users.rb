# frozen_string_literal: true

class AddUiPreferencesToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :ui_preferences, :jsonb, null: false, default: {}
  end
end
