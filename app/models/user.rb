# frozen_string_literal: true

class User < ApplicationRecord
  CURRENT_TERMS_VERSION = '2026-02-16'
  EMAIL_CHANGE_VERIFICATION_WINDOW = 1.hour
  attr_accessor :skip_terms_validation

  before_destroy :capture_workspace_ids_for_cleanup
  after_destroy_commit :destroy_unowned_or_empty_workspaces

  has_many :queries,
           dependent: :destroy,
           primary_key: :author_id,
           foreign_key: :id

  has_many :members,
           dependent: :destroy

  has_many :accepted_members,
           -> { accepted },
           class_name: 'Member',
           dependent: :destroy,
           inverse_of: :user

  has_many :workspaces,
           through: :accepted_members,
           source: :workspace

  normalizes :email, with: ->(email) { email.strip.downcase }
  normalizes :pending_email, with: ->(email) { email.strip.downcase }
  validates :terms_accepted_at, :terms_version, presence: true, on: :create, unless: :skip_terms_validation

  def full_name
    "#{first_name} #{last_name}"
  end

  def member_of?(workspace:)
    accepted_members.exists?(workspace_id: workspace.id)
  end

  def begin_email_change_verification!(new_email:)
    update!(
      pending_email: new_email,
      email_change_verification_token: SecureRandom.base58(24),
      email_change_verification_sent_at: Time.current
    )
  end

  def email_change_verification_expired?
    email_change_verification_sent_at.blank? ||
      email_change_verification_sent_at < EMAIL_CHANGE_VERIFICATION_WINDOW.ago
  end

  def verify_email_change_token?(token:)
    stored_token = email_change_verification_token.to_s
    submitted_token = token.to_s
    return false if stored_token.blank?
    return false if stored_token.bytesize != submitted_token.bytesize

    ActiveSupport::SecurityUtils.secure_compare(stored_token, submitted_token)
  end

  def confirm_email_change!(token:)
    return false unless verify_email_change_token?(token:)
    return false if email_change_verification_expired?
    return false if pending_email.blank?

    update!(
      email: pending_email,
      pending_email: nil,
      email_change_verification_token: nil,
      email_change_verification_sent_at: nil
    )

    true
  rescue ActiveRecord::RecordNotUnique
    false
  end

  def clear_email_change_verification!
    update!(
      pending_email: nil,
      email_change_verification_token: nil,
      email_change_verification_sent_at: nil
    )
  end

  private

  def capture_workspace_ids_for_cleanup
    @workspace_ids_for_cleanup = members.pluck(:workspace_id).uniq
  end

  def destroy_unowned_or_empty_workspaces
    Array(@workspace_ids_for_cleanup).each do |workspace_id|
      workspace = Workspace.find_by(id: workspace_id)
      next unless workspace
      next if workspace.members.accepted.exists?(role: Member::Roles::OWNER)

      notify_workspace_deleted_users!(workspace:)
      workspace.destroy!
    end
  end

  def notify_workspace_deleted_users!(workspace:)
    workspace.members.includes(:user).map(&:user).uniq.each do |workspace_user|
      WorkspaceMailer.workspace_deleted(
        user: workspace_user,
        workspace_name: workspace.name,
        workspace_owner_name: full_name
      ).deliver_now
    rescue StandardError => e
      Rails.logger.error("Workspace delete notification failed for user #{workspace_user.id}: #{e.class} #{e.message}")
    end
  end
end
