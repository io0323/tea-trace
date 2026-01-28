class Shipment < ApplicationRecord
  belongs_to :tea_lot

  validates :destination, presence: true
  validates :shipped_at, presence: true
  validates :quantity_kg, presence: true, numericality: { greater_than: 0 }
end
