# frozen_string_literal: true

module Staging
  module FakeWorkspaceSeedCatalog
    DEFAULT_PREFIX = 'Seed Workspace'
    DEFAULT_FAKE_EMAIL_DOMAIN = 'seed.sqlbook.test'
    CHRIS_EMAIL = 'chris.pattison@protonmail.com'
    CHRIS_ROLE_CYCLE = [
      Member::Roles::ADMIN,
      Member::Roles::USER,
      Member::Roles::READ_ONLY
    ].freeze
    TEAM_SIZE_PATTERN = [2, 3, 4, 5].freeze
    FIRST_NAMES = %w[
      Alice Sofia Noah Emma Lucas Mila Ethan Chloe Oscar Nina Leo Ruby
      Jack Maya Eli Zoe Finn Iris Max Layla Sam Ava Theo Hazel
    ].freeze
    LAST_NAMES = %w[
      Carter Bennett Hughes Foster Walsh Palmer Reid Sutton Griffin Brooks Harper Ellis
      Turner Morris Bailey Dixon Kennedy Porter Shaw Walters Dawson Perry Spencer Flynn
    ].freeze
  end
end
