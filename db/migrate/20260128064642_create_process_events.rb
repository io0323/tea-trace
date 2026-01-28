class CreateProcessEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :process_events do |t|
      t.references :tea_lot, null: false, foreign_key: true
      t.string :event_type
      t.datetime :occurred_at
      t.text :note

      t.timestamps
    end
  end
end
