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

ActiveRecord::Schema[8.1].define(version: 2026_11_18_020000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  # Custom types defined in this database.
  # Note that some types may not work with other database engines. Be careful if changing database.
  create_enum "badge_kind", ["first_check_in", "three_day_streak", "week_streak", "three_week_streak", "comeback", "finisher", "flawless", "cheerleader", "good_for_it"]
  create_enum "challenge_cadence", ["daily", "weekly"]
  create_enum "challenge_participant_status", ["active", "inactive"]
  create_enum "challenge_reward_status", ["pending", "fulfilled", "canceled"]
  create_enum "challenge_target_scope", ["each_time", "total"]
  create_enum "challenge_unit", ["reps", "minutes", "hours", "km", "pages"]
  create_enum "device_sign_in_state", ["pending", "approved", "used"]

  create_table "active_storage_attachments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.uuid "record_id", null: false
    t.uuid "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "badges", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "challenge_story_id"
    t.enum "kind", null: false, enum_type: "badge_kind"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["challenge_story_id"], name: "index_badges_on_challenge_story_id"
    t.index ["user_id", "kind", "challenge_story_id"], name: "index_badges_on_user_id_and_kind_and_challenge_story_id", unique: true, nulls_not_distinct: true
    t.index ["user_id"], name: "index_badges_on_user_id"
  end

  create_table "challenge_check_in_likes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "challenge_check_in_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["challenge_check_in_id"], name: "index_challenge_check_in_likes_on_challenge_check_in_id"
    t.index ["user_id", "challenge_check_in_id"], name: "index_comment_likes_on_user_and_comment", unique: true
    t.index ["user_id"], name: "index_challenge_check_in_likes_on_user_id"
  end

  create_table "challenge_check_in_replies", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "challenge_check_in_id", null: false
    t.uuid "user_id", null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["challenge_check_in_id", "created_at"], name: "idx_on_challenge_check_in_id_created_at_44c6211b2d"
    t.index ["challenge_check_in_id"], name: "index_challenge_check_in_replies_on_challenge_check_in_id"
    t.index ["user_id"], name: "index_challenge_check_in_replies_on_user_id"
    t.check_constraint "char_length(body) >= 1 AND char_length(body) <= 280", name: "check_reply_body_length"
  end

  create_table "challenge_check_ins", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "message", null: false
    t.uuid "challenge_participant_id", null: false
    t.uuid "challenge_story_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "challenge_check_in_likes_count", default: 0, null: false
    t.date "checked_in_on", null: false
    t.integer "challenge_check_in_replies_count", default: 0, null: false
    t.decimal "amount", precision: 10, scale: 2
    t.index ["challenge_participant_id", "checked_in_on"], name: "idx_on_challenge_participant_id_checked_in_on_b71ead7892"
    t.index ["challenge_participant_id"], name: "index_challenge_check_ins_on_challenge_participant_id"
    t.index ["challenge_story_id"], name: "index_challenge_check_ins_on_challenge_story_id"
    t.index ["created_at"], name: "index_challenge_check_ins_on_created_at"
    t.check_constraint "amount IS NULL OR amount > 0::numeric", name: "check_amount_positive"
    t.check_constraint "challenge_check_in_likes_count >= 0", name: "check_comment_likes_non_negative"
  end

  create_table "challenge_participants", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.uuid "user_id", null: false
    t.uuid "challenge_story_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "given_rewards_count", default: 0, null: false
    t.integer "received_rewards_count", default: 0, null: false
    t.integer "challenge_check_ins_count", default: 0, null: false
    t.enum "status", default: "active", null: false, enum_type: "challenge_participant_status"
    t.index ["challenge_story_id"], name: "index_challenge_participants_on_challenge_story_id"
    t.index ["status"], name: "index_challenge_participants_on_status"
    t.index ["user_id", "challenge_story_id"], name: "index_challenge_participants_on_user_id_and_challenge_story_id", unique: true
    t.index ["user_id"], name: "index_challenge_participants_on_user_id"
    t.check_constraint "challenge_check_ins_count >= 0", name: "check_comments_count_non_negative"
    t.check_constraint "given_rewards_count >= 0", name: "check_given_rewards_non_negative"
    t.check_constraint "received_rewards_count >= 0", name: "check_received_rewards_non_negative"
  end

  create_table "challenge_rewards", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "giver_id", null: false
    t.uuid "receiver_id", null: false
    t.uuid "challenge_story_id", null: false
    t.string "description", null: false
    t.datetime "fulfilled_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.enum "status", default: "pending", null: false, enum_type: "challenge_reward_status"
    t.index ["challenge_story_id"], name: "index_challenge_rewards_on_challenge_story_id"
    t.index ["fulfilled_at"], name: "index_challenge_rewards_on_fulfilled_at"
    t.index ["giver_id", "receiver_id", "challenge_story_id"], name: "index_challenge_rewards_on_participants_and_story", unique: true
    t.index ["giver_id"], name: "index_challenge_rewards_on_giver_id"
    t.index ["receiver_id"], name: "index_challenge_rewards_on_receiver_id"
    t.index ["status"], name: "index_challenge_rewards_on_status"
  end

  create_table "challenge_stories", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "title", null: false
    t.text "description", default: "", null: false
    t.date "start", null: false
    t.date "finish", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "completed", default: false, null: false
    t.integer "challenge_story_likes_count", default: 0, null: false
    t.integer "challenge_check_ins_count", default: 0, null: false
    t.integer "challenge_participants_count", default: 0, null: false
    t.integer "challenge_rewards_count", default: 0, null: false
    t.uuid "previous_challenge_story_id"
    t.integer "round", default: 1, null: false
    t.enum "cadence", default: "daily", null: false, enum_type: "challenge_cadence"
    t.integer "times_per_period", default: 1, null: false
    t.enum "unit", enum_type: "challenge_unit"
    t.decimal "target_amount", precision: 10, scale: 2
    t.enum "target_scope", enum_type: "challenge_target_scope"
    t.index ["completed"], name: "index_challenge_stories_on_completed"
    t.index ["created_at"], name: "index_challenge_stories_on_created_at"
    t.index ["finish"], name: "index_challenge_stories_on_finish"
    t.index ["previous_challenge_story_id"], name: "index_challenge_stories_on_previous_challenge_story_id", unique: true
    t.index ["start"], name: "index_challenge_stories_on_start"
    t.check_constraint "(target_amount IS NULL) = (target_scope IS NULL)", name: "check_target_complete"
    t.check_constraint "cadence = 'daily'::challenge_cadence AND times_per_period = 1 OR cadence = 'weekly'::challenge_cadence AND times_per_period >= 1 AND times_per_period <= 6", name: "check_times_per_period"
    t.check_constraint "challenge_check_ins_count >= 0", name: "check_story_comments_non_negative"
    t.check_constraint "challenge_participants_count >= 0", name: "check_participants_non_negative"
    t.check_constraint "challenge_rewards_count >= 0", name: "check_rewards_non_negative"
    t.check_constraint "challenge_story_likes_count >= 0", name: "check_story_likes_non_negative"
    t.check_constraint "char_length(description) <= 500", name: "check_description_length"
    t.check_constraint "finish >= start", name: "check_finish_after_start"
    t.check_constraint "round >= 1", name: "check_round_positive"
    t.check_constraint "target_amount IS NULL OR unit IS NOT NULL AND target_amount > 0::numeric", name: "check_target_needs_unit"
  end

  create_table "challenge_story_likes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "challenge_story_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["challenge_story_id"], name: "index_challenge_story_likes_on_challenge_story_id"
    t.index ["user_id", "challenge_story_id"], name: "index_challenge_story_likes_on_user_and_story", unique: true
    t.index ["user_id"], name: "index_challenge_story_likes_on_user_id"
  end

  create_table "credentials", force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "external_id", null: false
    t.string "public_key", null: false
    t.string "nickname"
    t.bigint "sign_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "backed_up"
    t.string "rp_id", null: false
    t.index ["external_id"], name: "index_credentials_on_external_id", unique: true
    t.index ["user_id", "rp_id"], name: "index_credentials_on_user_id_and_rp_id"
    t.index ["user_id"], name: "index_credentials_on_user_id"
  end

  create_table "device_sign_ins", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id"
    t.string "code", null: false
    t.enum "state", default: "pending", null: false, enum_type: "device_sign_in_state"
    t.string "user_agent"
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_device_sign_ins_on_code", unique: true, where: "(state = 'pending'::device_sign_in_state)"
    t.index ["expires_at"], name: "index_device_sign_ins_on_expires_at"
    t.index ["user_id"], name: "index_device_sign_ins_on_user_id"
    t.check_constraint "state = 'pending'::device_sign_in_state OR user_id IS NOT NULL", name: "check_device_sign_in_approved_by_user"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.citext "username", null: false
    t.string "webauthn_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "challenge_participants_count", default: 0, null: false
    t.integer "challenge_story_likes_count", default: 0, null: false
    t.string "email"
    t.datetime "email_verified_at"
    t.string "email_login_token"
    t.datetime "email_login_token_expires_at"
    t.datetime "last_email_sent_at"
    t.string "time_zone", default: "UTC", null: false
    t.integer "reminder_hour", default: 19
    t.date "last_reminded_on"
    t.string "payment_details"
    t.integer "badges_count", default: 0, null: false
    t.integer "challenge_check_in_replies_count", default: 0, null: false
    t.string "email_login_code_digest"
    t.integer "email_login_code_attempts", default: 0, null: false
    t.date "last_recapped_on"
    t.index ["email"], name: "index_users_on_email", unique: true, where: "(email IS NOT NULL)"
    t.index ["username"], name: "index_users_on_username", unique: true
    t.check_constraint "challenge_participants_count >= 0", name: "check_user_participants_non_negative"
    t.check_constraint "challenge_story_likes_count >= 0", name: "check_user_likes_non_negative"
    t.check_constraint "char_length(payment_details::text) <= 120", name: "check_user_payment_details_length"
    t.check_constraint "reminder_hour >= 0 AND reminder_hour <= 23", name: "check_user_reminder_hour_range"
  end

  create_table "web_push_notifications", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "endpoint", null: false
    t.string "auth_key", null: false
    t.string "p256dh_key", null: false
    t.string "device_name"
    t.text "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "endpoint"], name: "index_web_push_notifications_on_user_id_and_endpoint", unique: true
    t.index ["user_id"], name: "index_web_push_notifications_on_user_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "badges", "challenge_stories", on_delete: :cascade
  add_foreign_key "badges", "users", on_delete: :cascade
  add_foreign_key "challenge_check_in_likes", "challenge_check_ins", on_delete: :cascade
  add_foreign_key "challenge_check_in_likes", "users", on_delete: :cascade
  add_foreign_key "challenge_check_in_replies", "challenge_check_ins", on_delete: :cascade
  add_foreign_key "challenge_check_in_replies", "users", on_delete: :cascade
  add_foreign_key "challenge_check_ins", "challenge_participants", on_delete: :cascade
  add_foreign_key "challenge_check_ins", "challenge_stories", on_delete: :cascade
  add_foreign_key "challenge_participants", "challenge_stories", on_delete: :cascade
  add_foreign_key "challenge_participants", "users", on_delete: :cascade
  add_foreign_key "challenge_rewards", "challenge_participants", column: "giver_id", on_delete: :cascade
  add_foreign_key "challenge_rewards", "challenge_participants", column: "receiver_id", on_delete: :cascade
  add_foreign_key "challenge_rewards", "challenge_stories", on_delete: :cascade
  add_foreign_key "challenge_stories", "challenge_stories", column: "previous_challenge_story_id", on_delete: :nullify
  add_foreign_key "challenge_story_likes", "challenge_stories", on_delete: :cascade
  add_foreign_key "challenge_story_likes", "users", on_delete: :cascade
  add_foreign_key "credentials", "users", on_delete: :cascade
  add_foreign_key "device_sign_ins", "users", on_delete: :cascade
  add_foreign_key "web_push_notifications", "users", on_delete: :cascade
end
