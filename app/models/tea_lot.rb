class TeaLot < ApplicationRecord
  include Traceable
  include Reportable
  include Auditable

  has_many :process_events, dependent: :restrict_with_error
  has_many :shipments, dependent: :restrict_with_error

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
    when "received"
      "blue"
    when "processing"
      "yellow"
    when "shipped"
      "green"
    else
      "gray"
    end
  end

  def status_badge_color_class
    case status
    when "received"
      "bg-blue-100 text-blue-800"
    when "processing"
      "bg-yellow-100 text-yellow-800"
    when "shipped"
      "bg-green-100 text-green-800"
    else
      "bg-gray-100 text-gray-800"
    end
  end

  def status_text
    case status
    when "received"
      "受入済"
    when "processing"
      "加工中"
    when "shipped"
      "出荷済"
    else
      status
    end
  end

  def formatted_quantity
    sprintf("%.1f", quantity_kg)
  end
end
