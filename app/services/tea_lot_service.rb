class TeaLotService
  class << self
    def search_lots(query = nil)
      lots = TeaLot.includes(:process_events, :shipments)
      
      if query.present?
        search_term = "%#{query}%"
        lots = lots.where("lot_code ILIKE ? OR origin ILIKE ? OR variety ILIKE ?", 
                         search_term, search_term, search_term)
      end
      
      lots.order(harvest_date: :desc)
    end

    def update_status_based_on_events(tea_lot)
      events = tea_lot.process_events.order(:occurred_at)
      
      new_status = case
                   when events.where(event_type: 'packing').any?
                     'shipped'
                   when events.where(event_type: 'drying').any?
                     'processing'
                   when events.where(event_type: 'steaming').any?
                     'processing'
                   else
                     'received'
                   end
      
      tea_lot.update!(status: new_status) if tea_lot.status != new_status
    end

    def calculate_progress_percentage(tea_lot)
      events = tea_lot.process_events.pluck(:event_type)
      required_events = %w[steaming rolling drying packing]
      
      completed_events = events & required_events
      (completed_events.length.to_f / required_events.length * 100).round(1)
    end

    def get_next_expected_event(tea_lot)
      completed_events = tea_lot.process_events.pluck(:event_type)
      
      %w[steaming rolling drying packing].find do |event_type|
        !completed_events.include?(event_type)
      end
    end

    def generate_lot_report(tea_lot)
      {
        basic_info: {
          lot_code: tea_lot.lot_code,
          origin: tea_lot.origin,
          variety: tea_lot.variety,
          harvest_date: tea_lot.harvest_date,
          quantity_kg: tea_lot.quantity_kg,
          status: tea_lot.status,
          status_label: status_label(tea_lot.status)
        },
        progress: {
          percentage: calculate_progress_percentage(tea_lot),
          next_event: get_next_expected_event(tea_lot),
          total_events: tea_lot.process_events.count,
          completed_events: tea_lot.process_events.where.not(occurred_at: nil).count
        },
        timeline: tea_lot.process_events.order(:occurred_at).map do |event|
          {
            id: event.id,
            event_type: event.event_type,
            event_type_label: event.event_type_label,
            occurred_at: event.occurred_at,
            note: event.note
          }
        end,
        shipments: tea_lot.shipments.order(:shipped_at).map do |shipment|
          {
            id: shipment.id,
            destination: shipment.destination,
            shipped_at: shipment.shipped_at,
            quantity_kg: shipment.quantity_kg
          }
        end,
        summary: {
          total_shipped_quantity: tea_lot.shipments.sum(:quantity_kg),
          remaining_quantity: tea_lot.quantity_kg - tea_lot.shipments.sum(:quantity_kg),
          shipment_count: tea_lot.shipments.count,
          first_event_date: tea_lot.process_events.minimum(:occurred_at),
          last_event_date: tea_lot.process_events.maximum(:occurred_at)
        }
      }
    end

    def export_lots_to_csv(lots = nil)
      lots ||= TeaLot.includes(:process_events, :shipments).order(:lot_code)
      
      CSV.generate(headers: true) do |csv|
        csv << [
          'ロットコード', '産地', '品種', '収穫日', '数量(kg)', 'ステータス',
          '工程イベント数', '最新工程日', '出荷数', '総出荷量(kg)', '残量(kg)'
        ]
        
        lots.each do |lot|
          csv << [
            lot.lot_code,
            lot.origin,
            lot.variety,
            lot.harvest_date,
            lot.quantity_kg,
            status_label(lot.status),
            lot.process_events.count,
            lot.latest_event_date,
            lot.shipments.count,
            lot.shipments.sum(:quantity_kg),
            lot.quantity_kg - lot.shipments.sum(:quantity_kg)
          ]
        end
      end
    end

    def validate_lot_transition(tea_lot, new_status)
      current_events = tea_lot.process_events.pluck(:event_type)
      
      case new_status
      when 'processing'
        return current_events.include?('steaming')
      when 'shipped'
        return current_events.include?('packing')
      else
        return true
      end
    end

    def get_lots_by_status(status)
      TeaLot.where(status: status).includes(:process_events, :shipments)
                 .order(harvest_date: :desc)
    end

    def get_lots_by_date_range(start_date, end_date)
      TeaLot.where(harvest_date: start_date..end_date)
            .includes(:process_events, :shipments)
            .order(harvest_date: :desc)
    end

    def get_statistics
      total_lots = TeaLot.count
      lots_by_status = TeaLot.group(:status).count
      total_quantity = TeaLot.sum(:quantity_kg)
      total_shipped = Shipment.sum(:quantity_kg)
      
      {
        total_lots: total_lots,
        lots_by_status: lots_by_status,
        total_quantity: total_quantity,
        total_shipped: total_shipped,
        remaining_quantity: total_quantity - total_shipped,
        shipment_rate: total_quantity > 0 ? (total_shipped.to_f / total_quantity * 100).round(1) : 0
      }
    end

    private

    def status_label(status)
      case status
      when 'received'
        '受入済'
      when 'processing'
        '加工中'
      when 'shipped'
        '出荷済'
      else
        status
      end
    end
  end
end
