# frozen_string_literal: true

class User < ApplicationRecord
  has_many :queries,
           dependent: :destroy,
           primary_key: :author_id,
           foreign_key: :id

  has_many :members,
           dependent: :destroy

  has_many :workspaces,
           through: :members

  normalizes :email, with: ->(email) { email.strip.downcase }

  def full_name
    "#{first_name} #{last_name}"
  end
end
