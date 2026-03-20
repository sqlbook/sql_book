# frozen_string_literal: true

class DataSourcesStatsService
  attr_reader :total_events, :monthly_events

  def initialize(data_sources:)
    @data_sources = data_sources

    @total_events = tally_events_for(:total)
    @monthly_events = tally_events_for(:monthly)
  end

  def total_events_for(data_source:)
    return 0 unless data_source.capture_source?

    total_events[data_source.external_uuid].to_i
  end

  def monthly_events_for(data_source:)
    return 0 unless data_source.capture_source?

    monthly_events[data_source.external_uuid].to_i
  end

  def monthly_events_limit_for(data_source:)
    return nil unless data_source.capture_source?

    workspace = data_source.workspace
    capture_sources_count = workspace.data_sources.select(&:capture_source?).count
    return workspace.event_limit if capture_sources_count.zero?

    workspace.event_limit / capture_sources_count
  end

  def queries_for(data_source:)
    queries[data_source.id].to_i
  end

  def tables_for(data_source:)
    data_source.tables_count
  end

  def status_for(data_source:)
    return 'action_required' if data_source.capture_source? && !data_source.verified?
    return 'error' if data_source.last_error.present? || data_source.error?

    data_source.status
  end

  def last_checked_at_for(data_source:)
    data_source.last_checked_at
  end

  private

  attr_reader :data_sources

  def capture_data_sources
    @capture_data_sources ||= data_sources.select(&:capture_source?)
  end

  def data_source_id
    @data_source_id ||= data_sources.map(&:id)
  end

  def data_source_uuid
    @data_source_uuid ||= capture_data_sources.map(&:external_uuid)
  end

  # For each of the tables, fetch a tally of events and group
  # by the data_source_id. Merge all of the results to get
  # a single sum by data_source_id
  def tally_events_for(method)
    return {} if capture_data_sources.empty?

    EventRecord.all_event_types.each_with_object({}) do |model, result|
      data = send(:"#{method}_data_for", model)
      result.merge!(data) { |_, a, b| a + b }
    end
  rescue ActiveRecord::StatementInvalid => e
    # Event tables are protected by RLS policies that depend on a session variable.
    # If the variable is not set in this request path, avoid crashing workspace pages.
    raise unless missing_data_source_uuid_setting?(e)

    Rails.logger.warn('DataSourcesStatsService: skipping event tallies because app.current_data_source_uuid is unset')
    {}
  end

  def missing_data_source_uuid_setting?(error)
    error.message.include?('app.current_data_source_uuid')
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
