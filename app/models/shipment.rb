class Shipment < ApplicationRecord
  include Traceable
  include Auditable

  belongs_to :tea_lot

  validates :destination, presence: true
  validates :shipped_at, presence: true
  validates :quantity_kg, presence: true, numericality: { greater_than: 0 }

  def formatted_quantity
    sprintf('%.1f', quantity_kg)
  end
end
