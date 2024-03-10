# frozen_string_literal: true

class Member < ApplicationRecord
  belongs_to :workspace
  belongs_to :user

  belongs_to :invited_by,
             class_name: 'User',
             primary_key: :id,
             optional: true

  class Roles
    OWNER = 1
    ADMIN = 2
    READ_ONLY = 3
  end

  class Status
    ACCEPTED = 1
    PENDING = 2
  end

  def owner?
    role == Roles::OWNER
  end

  def admin?
    role == Roles::ADMIN
  end

  def read_only?
    role == Roles::READ_ONLY
  end

  def role_name
    names = {
      1 => 'Owner',
      2 => 'Admin',
      3 => 'Read only'
    }

    names[role]
  end

  def status_name
    names = {
      1 => 'Accepted',
      2 => 'Pending'
    }

    names[status]
  end
end
