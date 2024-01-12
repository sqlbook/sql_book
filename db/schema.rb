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

ActiveRecord::Schema[7.1].define(version: 2024_01_12_090044) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

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

  create_table "queries", force: :cascade do |t|
    t.string "query", null: false
    t.boolean "saved", default: false, null: false
    t.bigint "data_source_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["data_source_id"], name: "index_queries_on_data_source_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

end
