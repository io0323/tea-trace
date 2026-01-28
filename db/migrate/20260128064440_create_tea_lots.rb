class CreateTeaLots < ActiveRecord::Migration[8.1]
  def change
    create_table :tea_lots do |t|
      t.string :lot_code
      t.string :origin
      t.string :variety
      t.date :harvest_date
      t.decimal :quantity_kg
      t.string :status

      t.timestamps
    end
  end
end
