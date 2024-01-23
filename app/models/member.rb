# frozen_string_literal: true

class Member < ApplicationRecord
  belongs_to :workspace
  belongs_to :user

  class Roles
    OWNER = 1
  end
end
