# frozen_string_literal: true

class User < ApplicationRecord
  has_many :data_sources, dependent: :destroy

  has_many :queries, through: :data_sources

  normalizes :email, with: ->(email) { email.strip.downcase }
end
