# frozen_string_literal: true

class AddUserRoleToMembers < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL.squish
      UPDATE members
      SET role = 4
      WHERE role = 3
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE members
      SET role = 3
      WHERE role = 4
    SQL
  end
end
