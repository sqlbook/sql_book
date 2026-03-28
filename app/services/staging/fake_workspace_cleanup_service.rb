# frozen_string_literal: true

module Staging
  class FakeWorkspaceCleanupService
    DEFAULT_PREFIX = FakeWorkspaceSeedService::DEFAULT_PREFIX
    DEFAULT_FAKE_EMAIL_DOMAIN = FakeWorkspaceSeedService::DEFAULT_FAKE_EMAIL_DOMAIN

    Result = Struct.new(:deleted_workspaces, :deleted_users, keyword_init: true)

    def initialize(prefix: DEFAULT_PREFIX, fake_email_domain: DEFAULT_FAKE_EMAIL_DOMAIN)
      @prefix = prefix.to_s
      @fake_email_domain = fake_email_domain.to_s
    end

    def call
      deleted_workspaces = []
      deleted_users = []

      ActiveRecord::Base.transaction do
        seeded_workspaces.find_each do |workspace|
          deleted_workspaces << workspace.name
          workspace.destroy!
        end

        seeded_users.find_each do |user|
          deleted_users << user.email
          user.destroy!
        end
      end

      Result.new(deleted_workspaces:, deleted_users:)
    end

    private

    attr_reader :prefix, :fake_email_domain

    def seeded_workspaces
      Workspace.where('name LIKE ?', "#{prefix}%")
    end

    def seeded_users
      User.where('email LIKE ?', "%@#{fake_email_domain}")
    end
  end
end
