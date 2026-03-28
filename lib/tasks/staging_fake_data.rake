# frozen_string_literal: true

namespace :staging do
  namespace :fake_data do
    desc 'Seed fake workspaces and members for staging/dev chat testing'
    task seed_workspaces: :environment do
      abort_unless_supported_environment!

      result = Staging::FakeWorkspaceSeedService.new(
        count: ENV.fetch('COUNT', Staging::FakeWorkspaceSeedService::DEFAULT_COUNT),
        prefix: ENV.fetch('PREFIX', Staging::FakeWorkspaceSeedService::DEFAULT_PREFIX),
        fake_email_domain: ENV.fetch('FAKE_EMAIL_DOMAIN', Staging::FakeWorkspaceSeedService::DEFAULT_FAKE_EMAIL_DOMAIN),
        chris_email: ENV.fetch('CHRIS_EMAIL', Staging::FakeWorkspaceSeedService::CHRIS_EMAIL)
      ).call

      puts "Seeded #{result.created_workspaces.count} new fake workspaces"
      puts "Created #{result.created_users.count} new fake users"
      puts "Ensured #{result.attached_memberships.count} fake memberships"
    end

    desc 'Delete fake staging/dev workspaces and fake users created by staging:fake_data:seed_workspaces'
    task cleanup_workspaces: :environment do
      abort_unless_supported_environment!

      result = Staging::FakeWorkspaceCleanupService.new(
        prefix: ENV.fetch('PREFIX', Staging::FakeWorkspaceSeedService::DEFAULT_PREFIX),
        fake_email_domain: ENV.fetch('FAKE_EMAIL_DOMAIN', Staging::FakeWorkspaceSeedService::DEFAULT_FAKE_EMAIL_DOMAIN)
      ).call

      puts "Deleted #{result.deleted_workspaces.count} fake workspaces"
      puts "Deleted #{result.deleted_users.count} fake users"
    end

    def abort_unless_supported_environment!
      return if Rails.env.staging? || Rails.env.development?

      abort 'This task is only intended for staging or development.'
    end
  end
end
