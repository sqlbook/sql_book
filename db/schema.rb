# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2024_01_19_201605) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "clicks", force: :cascade do |t|
    t.uuid "data_source_uuid", null: false
    t.uuid "session_uuid", null: false
    t.uuid "visitor_uuid", null: false
    t.bigint "timestamp", null: false
    t.integer "coordinates_x", null: false
    t.integer "coordinates_y", null: false
    t.string "xpath", null: false
    t.string "inner_text"
    t.string "attribute_id"
    t.string "attribute_class"
    t.bigint "data_source_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["data_source_id"], name: "index_clicks_on_data_source_id"
  end

  create_table "data_sources", force: :cascade do |t|
    t.string "url", null: false
    t.uuid "external_uuid", default: -> { "gen_random_uuid()" }, null: false
    t.datetime "verified_at"
    t.bigint "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["external_uuid"], name: "index_data_sources_on_external_uuid", unique: true
    t.index ["url"], name: "index_data_sources_on_url", unique: true
    t.index ["user_id"], name: "index_data_sources_on_user_id"
  end

  create_table "one_time_passwords", force: :cascade do |t|
    t.string "email"
    t.string "token"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_one_time_passwords_on_email", unique: true
  end

  create_table "page_views", force: :cascade do |t|
    t.uuid "data_source_uuid", null: false
    t.uuid "session_uuid", null: false
    t.uuid "visitor_uuid", null: false
    t.bigint "timestamp", null: false
    t.string "url", null: false
    t.bigint "data_source_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["data_source_id"], name: "index_page_views_on_data_source_id"
  end

  create_table "queries", force: :cascade do |t|
    t.string "query", null: false
    t.boolean "saved", default: false, null: false
    t.bigint "data_source_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.index ["data_source_id"], name: "index_queries_on_data_source_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.uuid "data_source_uuid", null: false
    t.uuid "session_uuid", null: false
    t.uuid "visitor_uuid", null: false
    t.bigint "timestamp", null: false
    t.integer "viewport_x", null: false
    t.integer "viewport_y", null: false
    t.integer "device_x", null: false
    t.integer "device_y", null: false
    t.string "referrer"
    t.string "locale"
    t.string "useragent"
    t.string "browser"
    t.string "timezone"
    t.string "country_code"
    t.string "utm_source"
    t.string "utm_medium"
    t.string "utm_campaign"
    t.string "utm_content"
    t.string "utm_term"
    t.bigint "data_source_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["data_source_id"], name: "index_sessions_on_data_source_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

end
