# frozen_string_literal: true

class CreateClickHouseModels < ActiveRecord::Migration[7.1]
  def up # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    ClickHouse.connection.create_table(
      'sessions',
      engine: 'MergeTree',
      order: '(data_source_uuid, toDate(timestamp))',
      if_not_exists: true
    ) do |t|
      t.UUID   :uuid,             nullable: false
      t.UUID   :data_source_uuid, nullable: false
      t.UUID   :session_uuid,     nullable: false
      t.UUID   :visitor_uuid,     nullable: false
      t.Int16  :viewport_x,       nullable: false
      t.Int16  :viewport_y,       nullable: false
      t.Int16  :device_x,         nullable: false
      t.Int16  :device_y,         nullable: false
      t.Int64  :timestamp,        nullable: false
      t.String :referrer,         nullable: true
      t.String :locale,           nullable: true
      t.String :useragent,        nullable: true
      t.String :browser,          nullable: true
      t.String :device_type,      nullable: true
      t.String :timezone,         nullable: true
      t.String :country_code,     nullable: true
      t.String :utm_source,       nullable: true
      t.String :utm_medium,       nullable: true
      t.String :utm_campaign,     nullable: true
      t.String :utm_content,      nullable: true
      t.String :utm_term,         nullable: true
    end

    ClickHouse.connection.create_table(
      'clicks',
      engine: 'MergeTree',
      order: '(data_source_uuid, toDate(timestamp))',
      if_not_exists: true
    ) do |t|
      t.UUID   :uuid,             nullable: false
      t.UUID   :data_source_uuid, nullable: false
      t.UUID   :session_uuid,     nullable: false
      t.UUID   :visitor_uuid,     nullable: false
      t.Int64  :timestamp,        nullable: false
      t.Int16  :coordinates_x,    nullable: false
      t.Int16  :coordinates_y,    nullable: false
      t.String :xpath,            nullable: false
      t.String :inner_text,       nullable: true
      t.String :attribute_id,     nullable: true
      t.String :attribute_class,  nullable: true
    end

    ClickHouse.connection.create_table(
      'page_views',
      engine: 'MergeTree',
      order: '(data_source_uuid, toDate(timestamp))',
      if_not_exists: true
    ) do |t|
      t.UUID   :uuid,             nullable: false
      t.UUID   :data_source_uuid, nullable: false
      t.UUID   :session_uuid,     nullable: false
      t.UUID   :visitor_uuid,     nullable: false
      t.Int64  :timestamp,        nullable: false
      t.String :url,              nullable: false
    end
  end

  def down
    ClickHouse.connection.drop_table('sessions')
    ClickHouse.connection.drop_table('clicks')
    ClickHouse.connection.drop_table('page_views')
  end
end
