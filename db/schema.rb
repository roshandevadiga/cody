# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20180723042927) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "pgcrypto"

  create_table "api_keys", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.bigint "user_id"
    t.string "password_digest"
    t.index ["user_id"], name: "index_api_keys_on_user_id"
  end

  create_table "pull_requests", id: :serial, force: :cascade do |t|
    t.string "status"
    t.string "number"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "pending_reviews"
    t.string "completed_reviews"
    t.integer "parent_pull_request_id"
    t.bigint "repository_id"
    t.index ["parent_pull_request_id"], name: "index_pull_requests_on_parent_pull_request_id"
    t.index ["repository_id"], name: "index_pull_requests_on_repository_id"
  end

  create_table "repositories", force: :cascade do |t|
    t.string "name"
    t.string "owner"
    t.string "config_hash"
    t.index ["name", "owner"], name: "index_repositories_on_name_and_owner", unique: true
  end

  create_table "review_rules", id: :serial, force: :cascade do |t|
    t.string "name"
    t.string "type"
    t.string "file_match"
    t.string "reviewer"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "short_code"
    t.bigint "repository_id"
    t.boolean "active", default: true
    t.index ["repository_id"], name: "index_review_rules_on_repository_id"
    t.index ["short_code", "repository_id"], name: "index_review_rules_on_short_code_and_repository_id", unique: true
  end

  create_table "reviewers", force: :cascade do |t|
    t.string "login"
    t.string "status"
    t.text "context"
    t.bigint "review_rule_id"
    t.bigint "pull_request_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["pull_request_id"], name: "index_reviewers_on_pull_request_id"
    t.index ["review_rule_id"], name: "index_reviewers_on_review_rule_id"
  end

  create_table "settings", id: :serial, force: :cascade do |t|
    t.string "key"
    t.string "value"
    t.bigint "repository_id"
    t.index ["key", "value"], name: "index_settings_on_key_and_value", unique: true
    t.index ["repository_id"], name: "index_settings_on_repository_id"
  end

  create_table "user_preferences", force: :cascade do |t|
    t.bigint "user_id"
    t.boolean "send_new_reviews_summary"
    t.index ["user_id"], name: "index_user_preferences_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "login"
    t.string "email"
    t.string "name"
    t.string "uid"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "role"
  end

  create_table "versions", force: :cascade do |t|
    t.string "item_type", null: false
    t.integer "item_id", null: false
    t.string "event", null: false
    t.string "whodunnit"
    t.jsonb "object"
    t.datetime "created_at"
    t.jsonb "object_changes"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  add_foreign_key "api_keys", "users"
  add_foreign_key "pull_requests", "repositories"
  add_foreign_key "review_rules", "repositories"
  add_foreign_key "settings", "repositories"
  add_foreign_key "user_preferences", "users"
end
