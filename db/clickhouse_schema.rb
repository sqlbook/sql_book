# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# clickhouse:schema:load`. When creating a new database, `rails clickhouse:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ClickhouseActiverecord::Schema.define(version: 2024_01_05_210103) do

  # TABLE: clicks
  # SQL: CREATE TABLE sql_book.clicks ( `uuid` UUID, `data_source_uuid` UUID, `session_uuid` UUID, `visitor_uuid` UUID, `timestamp` Int64, `coordinates_x` UInt32, `coordinates_y` UInt32, `xpath` String, `inner_text` Nullable(String), `attribute_id` Nullable(String), `attribute_class` Nullable(String) ) ENGINE = MergeTree ORDER BY (data_source_uuid, toDate(timestamp)) SETTINGS index_granularity = 8192
# Could not dump table "clicks" because of following StandardError
#   Unknown type 'UUID' for column 'uuid'

  # TABLE: page_views
  # SQL: CREATE TABLE sql_book.page_views ( `uuid` UUID, `data_source_uuid` UUID, `session_uuid` UUID, `visitor_uuid` UUID, `timestamp` Int64, `url` String ) ENGINE = MergeTree ORDER BY (data_source_uuid, toDate(timestamp)) SETTINGS index_granularity = 8192
# Could not dump table "page_views" because of following StandardError
#   Unknown type 'UUID' for column 'uuid'

  # TABLE: sessions
  # SQL: CREATE TABLE sql_book.sessions ( `uuid` UUID, `data_source_uuid` UUID, `session_uuid` UUID, `visitor_uuid` UUID, `timestamp` Int64, `viewport_x` UInt32, `viewport_y` UInt32, `device_x` UInt32, `device_y` UInt32, `referrer` Nullable(String), `locale` Nullable(String), `useragent` Nullable(String), `browser` Nullable(String), `timezone` Nullable(String), `country_code` Nullable(String), `utm_source` Nullable(String), `utm_medium` Nullable(String), `utm_campaign` Nullable(String), `utm_content` Nullable(String), `utm_term` Nullable(String) ) ENGINE = MergeTree ORDER BY (data_source_uuid, toDate(timestamp)) SETTINGS index_granularity = 8192
# Could not dump table "sessions" because of following StandardError
#   Unknown type 'UUID' for column 'uuid'

end
