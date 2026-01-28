class ProcessEvent < ApplicationRecord
  include Traceable
  include Auditable

  belongs_to :tea_lot

  validates :event_type, presence: true, inclusion: { in: %w[steaming rolling drying packing] }
  validates :occurred_at, presence: true

  def event_type_label
    event_type.capitalize
  end
end
