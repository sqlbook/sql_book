# frozen_string_literal: true

class AddTermsAcceptanceToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :terms_accepted_at, :datetime
    add_column :users, :terms_version, :string
  end
end
