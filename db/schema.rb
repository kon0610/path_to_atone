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

ActiveRecord::Schema.define(version: 2024_12_26_022709) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "consumer_billings", force: :cascade do |t|
    t.bigint "consumer_id", null: false
    t.integer "initial_billing_amount", null: false
    t.integer "billing_balance"
    t.integer "payment_method", null: false
    t.string "billing_code", null: false
    t.integer "payment_status", null: false
    t.date "payment_due_date", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["consumer_id"], name: "index_consumer_billings_on_consumer_id"
  end

  create_table "consumer_credits", force: :cascade do |t|
    t.bigint "consumer_id", null: false
    t.bigint "consumer_transaction_id", null: false
    t.bigint "consumer_billing_id"
    t.integer "initial_consumer_credit", null: false
    t.integer "latest_consumer_credit"
    t.datetime "netting_datetime"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["consumer_billing_id"], name: "index_consumer_credits_on_consumer_billing_id"
    t.index ["consumer_id"], name: "index_consumer_credits_on_consumer_id"
    t.index ["consumer_transaction_id"], name: "index_consumer_credits_on_consumer_transaction_id"
  end

  create_table "consumer_debts", force: :cascade do |t|
    t.bigint "consumer_id", null: false
    t.bigint "receipt_id", null: false
    t.integer "initial_consumer_debt", null: false
    t.integer "latest_consumer_debt"
    t.datetime "netting_datetime"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["consumer_id"], name: "index_consumer_debts_on_consumer_id"
    t.index ["receipt_id"], name: "index_consumer_debts_on_receipt_id"
  end

  create_table "consumer_offset_events", force: :cascade do |t|
    t.bigint "consumer_debt_id"
    t.bigint "consumer_credit_id"
    t.datetime "offset_datetime", null: false
    t.integer "offset_amount", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["consumer_credit_id"], name: "index_consumer_offset_events_on_consumer_credit_id"
    t.index ["consumer_debt_id"], name: "index_consumer_offset_events_on_consumer_debt_id"
  end

  create_table "consumer_transactions", force: :cascade do |t|
    t.bigint "consumer_id", null: false
    t.bigint "consumer_billing_id"
    t.integer "amount", null: false
    t.datetime "registration_datetime", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["consumer_billing_id"], name: "index_consumer_transactions_on_consumer_billing_id"
    t.index ["consumer_id"], name: "index_consumer_transactions_on_consumer_id"
  end

  create_table "consumers", force: :cascade do |t|
    t.string "full_name", null: false
    t.integer "age", null: false
    t.string "phone_number", null: false
    t.datetime "member_registration_datetime", null: false
    t.integer "member_code", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["member_code"], name: "index_consumers_on_member_code", unique: true
  end

  create_table "payments", force: :cascade do |t|
    t.integer "amount"
    t.datetime "payment_time"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "receipts", force: :cascade do |t|
    t.bigint "consumer_billing_id", null: false
    t.integer "payment_amount", null: false
    t.integer "balance"
    t.date "payment_date", null: false
    t.datetime "offset_completed_datetime"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["consumer_billing_id"], name: "index_receipts_on_consumer_billing_id"
  end

  add_foreign_key "consumer_billings", "consumers"
  add_foreign_key "consumer_credits", "consumer_billings"
  add_foreign_key "consumer_credits", "consumer_transactions"
  add_foreign_key "consumer_credits", "consumers"
  add_foreign_key "consumer_debts", "consumers"
  add_foreign_key "consumer_debts", "receipts"
  add_foreign_key "consumer_offset_events", "consumer_credits"
  add_foreign_key "consumer_offset_events", "consumer_debts"
  add_foreign_key "consumer_transactions", "consumer_billings"
  add_foreign_key "consumer_transactions", "consumers"
  add_foreign_key "receipts", "consumer_billings"
end
