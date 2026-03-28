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
      Result.new(
        deleted_workspaces: destroy_seeded_workspaces,
        deleted_users: destroy_seeded_users
      )
    end

    private

    attr_reader :prefix, :fake_email_domain

    def destroy_seeded_workspaces
      destroy_records(seeded_workspaces, &:name)
    end

    def destroy_seeded_users
      destroy_records(seeded_users, &:email)
    end

    def destroy_records(scope)
      deleted_values = []

      ActiveRecord::Base.transaction do
        scope.find_each do |record|
          deleted_values << yield(record)
          record.destroy!
        end
      end

      deleted_values
    end

    def seeded_workspaces
      Workspace.where('name LIKE ?', "#{prefix}%")
    end

    def seeded_users
      User.where('email LIKE ?', "%@#{fake_email_domain}")
    end
  end
end
