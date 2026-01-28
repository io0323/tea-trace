class CreateShipments < ActiveRecord::Migration[8.1]
  def change
    create_table :shipments do |t|
      t.references :tea_lot, null: false, foreign_key: true
      t.string :destination
      t.date :shipped_at
      t.decimal :quantity_kg

      t.timestamps
    end
  end
end
