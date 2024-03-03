# frozen_string_literal: true

class Workspace < ApplicationRecord
  has_many :data_sources,
           dependent: :destroy

  has_many :members,
           dependent: :destroy

  has_many :queries,
           through: :data_sources

  def owner
    members.find_by(role: Member::Roles::OWNER).user
  end

  # Placeholder until billing is in
  def event_limit
    15_000
  end
end
