# frozen_string_literal: true

class User < ApplicationRecord
  has_many :data_sources, dependent: :destroy

  has_many :queries,
           dependent: :destroy,
           primary_key: :author_id,
           foreign_key: :id

  normalizes :email, with: ->(email) { email.strip.downcase }

  def full_name
    "#{first_name} #{last_name}"
  end
end
