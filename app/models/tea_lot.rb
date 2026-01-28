class TeaLot < ApplicationRecord
  has_many :process_events, dependent: :destroy
  has_many :shipments, dependent: :destroy

  validates :lot_code, presence: true, uniqueness: true
  validates :origin, presence: true
  validates :variety, presence: true
  validates :harvest_date, presence: true
  validates :quantity_kg, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true, inclusion: { in: %w[received processing shipped] }

  def latest_event_date
    process_events.maximum(:occurred_at)
  end

  def status_badge_color
    case status
    when 'received'
      'blue'
    when 'processing'
      'yellow'
    when 'shipped'
      'green'
    else
      'gray'
    end
  end
end
