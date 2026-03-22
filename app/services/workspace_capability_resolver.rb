# frozen_string_literal: true

class WorkspaceCapabilityResolver
  attr_reader :workspace, :actor

  def initialize(workspace:, actor:)
    @workspace = workspace
    @actor = actor
  end

  def role
    @role ||= workspace.members.find_by(user_id: actor.id)&.role
  end

  def can_manage_workspace_settings?
    [Member::Roles::OWNER, Member::Roles::ADMIN].include?(role)
  end

  def can_manage_workspace_members?
    can_manage_workspace_settings?
  end

  def can_view_team_members?
    can_manage_workspace_members?
  end

  def can_manage_data_sources?
    can_manage_workspace_settings?
  end

  def can_view_data_sources?
    !role.in?([nil, Member::Roles::READ_ONLY])
  end

  def can_view_queries?
    role.present?
  end

  def can_write_queries?
    !role.in?([nil, Member::Roles::READ_ONLY])
  end

  def can_write_dashboards?
    can_write_queries?
  end

  def can_destroy_dashboards?
    [Member::Roles::OWNER, Member::Roles::ADMIN].include?(role)
  end

  def can_destroy_query?(query:)
    return false if role.nil? || role == Member::Roles::READ_ONLY
    return true if [Member::Roles::OWNER, Member::Roles::ADMIN].include?(role)

    query.author_id == actor.id
  end

  def summary
    {
      role:,
      role_name: Member.role_name_for(role),
      can_manage_workspace_settings: can_manage_workspace_settings?,
      can_manage_workspace_members: can_manage_workspace_members?,
      can_view_team_members: can_view_team_members?,
      can_manage_data_sources: can_manage_data_sources?,
      can_view_data_sources: can_view_data_sources?,
      can_view_queries: can_view_queries?,
      can_write_queries: can_write_queries?,
      can_write_dashboards: can_write_dashboards?,
      can_destroy_dashboards: can_destroy_dashboards?
    }
  end
end
