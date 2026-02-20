# frozen_string_literal: true

module BreadcrumbsHelper
  SECTION_BREADCRUMB_BUILDERS = {
    'app/workspaces' => :workspace_settings_breadcrumb_items,
    'app/workspaces/data_sources' => :data_source_section_breadcrumb_items,
    'app/workspaces/data_sources/set_up' => :data_source_setup_breadcrumb_items,
    'app/workspaces/queries' => :query_library_breadcrumb_items,
    'app/workspaces/data_sources/queries' => :query_section_breadcrumb_items,
    'app/workspaces/dashboards' => :dashboard_section_breadcrumb_items
  }.freeze

  def show_workspace_breadcrumbs?
    app_page? &&
      workspace_for_breadcrumbs.present? &&
      !workspace_home_page? &&
      !workspace_settings_panel_page?
  end

  def workspace_breadcrumb_items
    return [] unless show_workspace_breadcrumbs?

    [
      breadcrumb_item(label: 'Workspaces', path: app_workspaces_path),
      breadcrumb_item(label: workspace_for_breadcrumbs.name, path: workspace_settings_breadcrumb_path),
      *workspace_section_breadcrumb_items
    ]
  end

  private

  def workspace_settings_breadcrumb_path
    workspace = workspace_for_breadcrumbs
    return nil unless can_manage_workspace_settings?(workspace:)

    app_workspace_path(workspace)
  end

  def workspace_section_breadcrumb_items
    builder = SECTION_BREADCRUMB_BUILDERS[controller_path]
    return [] unless builder

    send(builder)
  end

  def workspace_settings_breadcrumb_items = [breadcrumb_item(label: 'Workspace Settings')]

  def query_library_breadcrumb_items = [breadcrumb_item(label: 'Query Library')]

  def data_source_section_breadcrumb_items
    if action_name == 'new'
      [
        breadcrumb_item(label: 'Data Sources', path: app_workspace_data_sources_path(workspace_for_breadcrumbs)),
        breadcrumb_item(label: 'New Data Source')
      ]
    elsif action_name == 'show'
      [
        breadcrumb_item(label: 'Data Sources', path: app_workspace_data_sources_path(workspace_for_breadcrumbs)),
        breadcrumb_item(label: data_source_breadcrumb_label)
      ]
    else
      [breadcrumb_item(label: 'Data Sources')]
    end
  end

  def data_source_setup_breadcrumb_items
    [
      breadcrumb_item(label: 'Data Sources', path: app_workspace_data_sources_path(workspace_for_breadcrumbs)),
      breadcrumb_item(
        label: data_source_breadcrumb_label,
        path: app_workspace_data_source_path(workspace_for_breadcrumbs, view_assign(:data_source))
      ),
      breadcrumb_item(label: 'Set Up')
    ]
  end

  def query_section_breadcrumb_items
    [
      breadcrumb_item(label: 'Query Library', path: app_workspace_queries_path(workspace_for_breadcrumbs)),
      breadcrumb_item(label: query_breadcrumb_label)
    ]
  end

  def dashboard_section_breadcrumb_items
    if action_name == 'new'
      [
        breadcrumb_item(label: 'Dashboards', path: app_workspace_dashboards_path(workspace_for_breadcrumbs)),
        breadcrumb_item(label: 'New Dashboard')
      ]
    elsif action_name == 'show'
      [
        breadcrumb_item(label: 'Dashboards', path: app_workspace_dashboards_path(workspace_for_breadcrumbs)),
        breadcrumb_item(label: dashboard_breadcrumb_label)
      ]
    else
      [breadcrumb_item(label: 'Dashboards')]
    end
  end

  def data_source_breadcrumb_label
    view_assign(:data_source)&.url || 'Data Source'
  end

  def query_breadcrumb_label
    view_assign(:query)&.name.presence || 'Query'
  end

  def dashboard_breadcrumb_label
    view_assign(:dashboard)&.name.presence || 'Dashboard'
  end

  def workspace_for_breadcrumbs = view_assign(:workspace)

  def view_assign(name) = controller.view_assigns[name.to_s]

  def breadcrumb_item(label:, path: nil) = { label:, path: }

  def workspace_home_page?
    controller_path == 'app/workspaces' && action_name == 'index'
  end

  def workspace_settings_panel_page?
    controller_path == 'app/workspaces' && action_name == 'show'
  end
end
