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

ActiveRecord::Schema.define(version: 20180706143846) do

  create_table "server_deploys", force: :cascade do |t|
    t.integer "server_id"
    t.string "git_branch"
    t.string "commit_hash"
    t.string "git_user"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "git_commit_message"
  end

  create_table "servers", force: :cascade do |t|
    t.string "name"
    t.string "description"
    t.string "logo_url"
    t.string "status"
    t.datetime "reserved_until"
    t.string "reserved_for"
    t.string "slack_channel"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "server_url"
    t.string "git_remote"
    t.string "jira_iframe_url"
  end

end
