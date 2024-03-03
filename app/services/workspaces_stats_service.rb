# frozen_string_literal: true

class WorkspacesStatsService
  def initialize(workspaces:)
    @workspaces = workspaces

    @monthly_events = data_sources_stats.monthly_events
  end

  def monthly_events_for(workspace:)
    workspace
      .data_sources
      .map { |data_source| monthly_events[data_source.external_uuid].to_i }
      .reduce(:+)
  end

  def monthly_events_limit_for(workspace:)
    workspace.event_limit
  end

  private

  attr_reader :workspaces, :monthly_events

  def data_sources
    workspaces.map(&:data_sources).flatten
  end

  def data_sources_stats
    @data_sources_stats ||= DataSourcesStatsService.new(data_sources:)
  end
end
