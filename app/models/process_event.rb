class ProcessEvent < ApplicationRecord
  include Traceable
  include Auditable

  belongs_to :tea_lot

  validates :event_type, presence: true, inclusion: { in: %w[steaming rolling drying packing] }
  validates :occurred_at, presence: true

  def event_type_label
    case event_type
    when 'steaming'
      '蒸熱'
    when 'rolling'
      '揉捻'
    when 'drying'
      '乾燥'
    when 'packing'
      '包装'
    else
      event_type
    end
  end
end
