# frozen_string_literal: true

class User < ApplicationRecord
  CURRENT_TERMS_VERSION = '2026-02-16'.freeze

  has_many :queries,
           dependent: :destroy,
           primary_key: :author_id,
           foreign_key: :id

  has_many :members,
           dependent: :destroy

  has_many :workspaces,
           through: :members

  normalizes :email, with: ->(email) { email.strip.downcase }
  validates :terms_accepted_at, :terms_version, presence: true, on: :create

  def full_name
    "#{first_name} #{last_name}"
  end

  def member_of?(workspace:)
    workspaces.exists?(id: workspace.id)
  end
end
