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

ActiveRecord::Schema[8.1].define(version: 2026_02_01_151115) do
  create_table "process_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "event_type"
    t.text "note"
    t.datetime "occurred_at"
    t.integer "tea_lot_id", null: false
    t.datetime "updated_at", null: false
    t.index ["tea_lot_id"], name: "index_process_events_on_tea_lot_id"
  end

  create_table "shipments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "destination"
    t.text "notes"
    t.decimal "quantity_kg"
    t.date "shipped_at"
    t.integer "tea_lot_id", null: false
    t.datetime "updated_at", null: false
    t.index ["tea_lot_id"], name: "index_shipments_on_tea_lot_id"
  end

  create_table "tea_lots", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "harvest_date"
    t.string "lot_code"
    t.string "origin"
    t.decimal "quantity_kg"
    t.string "status"
    t.datetime "updated_at", null: false
    t.string "variety"
  end

  add_foreign_key "process_events", "tea_lots"
  add_foreign_key "shipments", "tea_lots"
end
