# frozen_string_literal: true

class User < ApplicationRecord
  CURRENT_TERMS_VERSION = '2026-02-16'
  attr_accessor :skip_terms_validation

  has_many :queries,
           dependent: :destroy,
           primary_key: :author_id,
           foreign_key: :id

  has_many :members,
           dependent: :destroy

  has_many :accepted_members,
           -> { accepted },
           class_name: 'Member',
           inverse_of: :user

  has_many :workspaces,
           through: :accepted_members,
           source: :workspace

  normalizes :email, with: ->(email) { email.strip.downcase }
  validates :terms_accepted_at, :terms_version, presence: true, on: :create, unless: :skip_terms_validation

  def full_name
    "#{first_name} #{last_name}"
  end

  def member_of?(workspace:)
    accepted_members.exists?(workspace_id: workspace.id)
  end
end
