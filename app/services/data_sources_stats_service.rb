# frozen_string_literal: true

class DataSourcesStatsService
  attr_reader :total_events, :monthly_events

  def initialize(data_sources:)
    @data_sources = data_sources

    @total_events = tally_events_for(:total)
    @monthly_events = tally_events_for(:monthly)
  end

  def total_events_for(data_source:)
    total_events[data_source.external_uuid].to_i
  end

  def monthly_events_for(data_source:)
    monthly_events[data_source.external_uuid].to_i
  end

  def monthly_events_limit_for(data_source:)
    workspace = data_source.workspace
    workspace.event_limit / workspace.data_sources.count
  end

  def queries_for(data_source:)
    queries[data_source.id].to_i
  end

  private

  attr_reader :data_sources

  def data_source_id
    @data_source_id ||= data_sources.map(&:id)
  end

  def data_source_uuid
    @data_source_uuid ||= data_sources.map(&:external_uuid)
  end

  # For each of the tables, fetch a tally of events and group
  # by the data_source_id. Merge all of the results to get
  # a single sum by data_source_id
  def tally_events_for(method)
    EventRecord.all_event_types.inject({}) do |result, model|
      data = send(:"#{method}_data_for", model)
      result.merge(data) { |_, a, b| a + b }
    end
  end

  # Fetch the count of events for the data sources for all time
  def total_data_for(model)
    model.where(data_source_uuid:).group(:data_source_uuid).count
  end

  # Fetch the count of events for the data sources for the
  # current month
  def monthly_data_for(model)
    from_timestamp = Time.current.beginning_of_month.to_i

    model
      .where('data_source_uuid in (?) AND timestamp >= ?', data_source_uuid, from_timestamp)
      .group(:data_source_uuid)
      .count
  end

  # Fetch the number of saved queries for all the data sources
  def queries
    @queries ||= Query.where(data_source_id:, saved: true).group(:data_source_id).count
  end
end
