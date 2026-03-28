# frozen_string_literal: true

module Staging
  class FakeWorkspaceSeedService # rubocop:disable Metrics/ClassLength
    DEFAULT_COUNT = 12
    DEFAULT_PREFIX = FakeWorkspaceSeedCatalog::DEFAULT_PREFIX
    DEFAULT_FAKE_EMAIL_DOMAIN = FakeWorkspaceSeedCatalog::DEFAULT_FAKE_EMAIL_DOMAIN
    CHRIS_EMAIL = FakeWorkspaceSeedCatalog::CHRIS_EMAIL
    CHRIS_ROLE_CYCLE = FakeWorkspaceSeedCatalog::CHRIS_ROLE_CYCLE
    TEAM_SIZE_PATTERN = FakeWorkspaceSeedCatalog::TEAM_SIZE_PATTERN
    FIRST_NAMES = FakeWorkspaceSeedCatalog::FIRST_NAMES
    LAST_NAMES = FakeWorkspaceSeedCatalog::LAST_NAMES

    Result = Struct.new(:created_workspaces, :created_users, :attached_memberships, keyword_init: true)

    def initialize(
      count: DEFAULT_COUNT,
      prefix: DEFAULT_PREFIX,
      fake_email_domain: DEFAULT_FAKE_EMAIL_DOMAIN,
      chris_email: CHRIS_EMAIL
    )
      @count = count.to_i
      @prefix = prefix.to_s
      @fake_email_domain = fake_email_domain.to_s
      @chris_email = chris_email.to_s.downcase
      @name_cursor = 0
      @created_workspaces = []
      @created_users = []
      @attached_memberships = []
    end

    def call
      validate_arguments!
      chris = User.find_by!(email: chris_email)

      ActiveRecord::Base.transaction do
        count.times { |index| seed_workspace!(index:, chris:) }
      end

      result
    end

    private

    attr_reader :count, :prefix, :fake_email_domain, :chris_email,
                :created_workspaces, :created_users, :attached_memberships

    def validate_arguments!
      raise ArgumentError, 'count must be positive' if count <= 0
      raise ArgumentError, 'prefix must be present' if prefix.blank?
      raise ArgumentError, 'fake_email_domain must be present' if fake_email_domain.blank?
    end

    def result
      Result.new(
        created_workspaces: created_workspaces.uniq,
        created_users: created_users.uniq,
        attached_memberships: attached_memberships.uniq
      )
    end

    def seed_workspace!(index:, chris:)
      workspace_number = index + 1
      workspace_created_at = workspace_timestamp(index:)
      workspace = ensure_workspace!(workspace_number:, created_at: workspace_created_at)

      attach_owner!(workspace:, workspace_number:, created_at: workspace_created_at)
      attach_chris!(workspace:, chris:, index:, created_at: workspace_created_at)
      attach_teammates!(workspace:, workspace_number:, index:, created_at: workspace_created_at)
    end

    def ensure_workspace!(workspace_number:, created_at:)
      workspace_name = format('%<prefix>s %<number>02d', prefix:, number: workspace_number)
      workspace = Workspace.find_or_initialize_by(name: workspace_name)
      workspace.assign_attributes(created_at:, updated_at: created_at)
      workspace.save! if workspace.new_record? || workspace.changed?
      created_workspaces << workspace if workspace.previous_changes.key?('id')
      workspace
    end

    def attach_owner!(workspace:, workspace_number:, created_at:)
      owner = seed_user_for!(
        workspace_number:,
        slot: 0,
        role: Member::Roles::OWNER,
        created_at:
      )
      record_created_user(owner)
      attached_memberships << ensure_membership!(
        workspace:,
        user: owner,
        role: Member::Roles::OWNER,
        created_at:
      )
    end

    def attach_chris!(workspace:, chris:, index:, created_at:)
      chris_role = CHRIS_ROLE_CYCLE[index % CHRIS_ROLE_CYCLE.length]
      attached_memberships << ensure_membership!(
        workspace:,
        user: chris,
        role: chris_role,
        created_at: created_at + 5.minutes
      )
    end

    def attach_teammates!(workspace:, workspace_number:, index:, created_at:)
      extra_member_count(index:).times do |slot_offset|
        slot = slot_offset + 1
        member_created_at = created_at + (slot + 1).hours
        teammate = seed_user_for!(
          workspace_number:,
          slot:,
          role: seed_role_for(slot:),
          created_at: member_created_at
        )
        record_created_user(teammate)
        attached_memberships << ensure_membership!(
          workspace:,
          user: teammate,
          role: teammate_role_for(slot:),
          created_at: member_created_at
        )
      end
    end

    def record_created_user(user)
      created_users << user if user.previous_changes.key?('id')
    end

    def extra_member_count(index:)
      TEAM_SIZE_PATTERN[index % TEAM_SIZE_PATTERN.length] - 2
    end

    def seed_role_for(slot:)
      slot.even? ? Member::Roles::ADMIN : Member::Roles::USER
    end

    def teammate_role_for(slot:)
      (slot % 3).zero? ? Member::Roles::READ_ONLY : Member::Roles::USER
    end

    def workspace_timestamp(index:)
      Time.zone.now.beginning_of_day - (count - index).days - (index * 3).hours
    end

    def seed_user_for!(workspace_number:, slot:, role:, created_at:)
      email = fake_email_for(workspace_number:, slot:, role:)
      user = User.find_or_initialize_by(email:)
      first_name, last_name = next_name_pair

      user.assign_attributes(
        first_name:,
        last_name:,
        terms_accepted_at: created_at - 2.days,
        terms_version: User::CURRENT_TERMS_VERSION,
        preferred_locale: slot.even? ? 'en' : 'es',
        super_admin: false,
        last_active_at: created_at + 1.day,
        created_at: created_at - 7.days,
        updated_at: created_at + 2.days
      )
      user.save! if user.new_record? || user.changed?
      user
    end

    def ensure_membership!(workspace:, user:, role:, created_at:)
      membership = Member.find_or_initialize_by(workspace:, user:)
      membership.assign_attributes(
        role:,
        status: Member::Status::ACCEPTED,
        invitation: nil,
        invited_by_id: nil,
        created_at: membership.created_at || created_at,
        updated_at: created_at
      )
      membership.save! if membership.new_record? || membership.changed?
      membership
    end

    def fake_email_for(workspace_number:, slot:, role:)
      role_slug = Member.role_name_for(role).to_s.downcase.parameterize(separator: '_')
      "workspace_#{workspace_number}_#{role_slug}_#{slot}@#{fake_email_domain}"
    end

    def next_name_pair
      first_name = FIRST_NAMES[@name_cursor % FIRST_NAMES.length]
      last_name = LAST_NAMES[@name_cursor % LAST_NAMES.length]
      @name_cursor += 1
      [first_name, last_name]
    end
  end
end
