class AddNotesToShipments < ActiveRecord::Migration[8.1]
  def change
    add_column :shipments, :notes, :text
  end
end
