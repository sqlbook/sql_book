# frozen_string_literal: true

class Member < ApplicationRecord
  ROLE_LABEL_KEYS = {
    1 => 'models.member.roles.owner',
    2 => 'models.member.roles.admin',
    3 => 'models.member.roles.user',
    4 => 'models.member.roles.read_only'
  }.freeze

  ROLE_LABEL_FALLBACKS = {
    1 => 'Owner',
    2 => 'Admin',
    3 => 'User',
    4 => 'Read only'
  }.freeze

  STATUS_LABEL_KEYS = {
    1 => 'models.member.statuses.accepted',
    2 => 'models.member.statuses.pending'
  }.freeze

  STATUS_LABEL_FALLBACKS = {
    1 => 'Accepted',
    2 => 'Pending'
  }.freeze

  belongs_to :workspace
  belongs_to :user

  belongs_to :invited_by,
             class_name: 'User',
             primary_key: :id,
             optional: true

  class Roles
    OWNER = 1
    ADMIN = 2
    USER = 3
    READ_ONLY = 4
  end

  class Status
    ACCEPTED = 1
    PENDING = 2
  end

  scope :accepted, -> { where(status: Status::ACCEPTED) }
  scope :pending, -> { where(status: Status::PENDING) }

  after_commit :broadcast_realtime_updates

  def owner?
    role == Roles::OWNER
  end

  def admin?
    role == Roles::ADMIN
  end

  def read_only?
    role == Roles::READ_ONLY
  end

  def user?
    role == Roles::USER
  end

  def pending?
    status == Status::PENDING
  end

  def role_name
    self.class.role_name_for(role)
  end

  def status_name
    self.class.status_name_for(status)
  end

  private

  class << self
    def role_name_for(role_value, locale: I18n.locale)
      translate_enum_label(
        value: role_value,
        key_map: ROLE_LABEL_KEYS,
        fallback_map: ROLE_LABEL_FALLBACKS,
        locale:
      )
    end

    def status_name_for(status_value, locale: I18n.locale)
      translate_enum_label(
        value: status_value,
        key_map: STATUS_LABEL_KEYS,
        fallback_map: STATUS_LABEL_FALLBACKS,
        locale:
      )
    end

    private

    def translate_enum_label(value:, key_map:, fallback_map:, locale:)
      normalized = value.to_i
      key = key_map[normalized]
      return nil if key.blank?

      I18n.t(key, locale:, default: fallback_map[normalized])
    end
  end

  def broadcast_realtime_updates
    workspace_record = Workspace.find_by(id: workspace_id)
    return unless workspace_record

    RealtimeUpdatesService.refresh_workspace_members(workspace: workspace_record)
    RealtimeUpdatesService.refresh_users_app(users: realtime_refresh_users)
  end

  def realtime_refresh_users
    Array(user).compact
  end
end
