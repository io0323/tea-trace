class ShipmentService
  class << self
    def create_shipment(tea_lot, shipment_params)
      Shipment.transaction do
        shipment = tea_lot.shipments.build(shipment_params)
        
        # Validate that we have enough quantity
        total_shipped = tea_lot.shipments.sum(:quantity_kg) + shipment.quantity_kg
        
        if total_shipped > tea_lot.quantity_kg
          raise ActiveRecord::RecordInvalid, "出荷量が利用可能量を超えています。残量: #{tea_lot.quantity_kg - tea_lot.shipments.sum(:quantity_kg)}kg"
        end
        
        if shipment.save
          # Update tea lot status if all quantity is shipped
          if total_shipped >= tea_lot.quantity_kg
            tea_lot.update!(status: 'shipped')
          end
          
          # Log the shipment creation
          Rails.logger.info "Shipment created: #{shipment.id} for TeaLot: #{tea_lot.lot_code}, Quantity: #{shipment.quantity_kg}kg"
          
          shipment
        else
          raise ActiveRecord::RecordInvalid, shipment
        end
      end
    end

    def get_available_quantity(tea_lot)
      tea_lot.quantity_kg - tea_lot.shipments.sum(:quantity_kg)
    end

    def get_shipments_by_destination(destination)
      Shipment.where("destination ILIKE ?", "%#{destination}%")
              .includes(:tea_lot)
              .order(shipped_at: :desc)
    end

    def get_shipments_in_date_range(start_date, end_date)
      Shipment.where(shipped_at: start_date..end_date)
              .includes(:tea_lot)
              .order(shipped_at: :desc)
    end

    def get_shipment_statistics
      total_shipments = Shipment.count
      total_quantity = Shipment.sum(:quantity_kg)
      shipments_by_destination = Shipment.group(:destination).count
      shipments_by_month = Shipment.group_by_month(:shipped_at).count
      
      {
        total_shipments: total_shipments,
        total_quantity: total_quantity,
        average_quantity_per_shipment: total_shipments > 0 ? (total_quantity.to_f / total_shipments).round(2) : 0,
        shipments_by_destination: shipments_by_destination,
        shipments_by_month: shipments_by_month
      }
    end

    def get_top_destinations(limit = 10)
      Shipment.joins(:tea_lot)
              .select('destinations.destination, SUM(shipments.quantity_kg) as total_quantity, COUNT(*) as shipment_count')
              .group('destinations.destination')
              .order('total_quantity DESC')
              .limit(limit)
    end

    def get_shipment_trends(days = 30)
      start_date = days.days.ago.to_date
      
      shipments = Shipment.where(shipped_at: start_date..Date.current)
                         .group_by_day(:shipped_at)
                         .sum(:quantity_kg)
      
      # Fill in missing days with 0
      (start_date..Date.current).each do |date|
        shipments[date] ||= 0
      end
      
      shipments.sort.to_h
    end

    def export_shipments_to_csv(shipments = nil)
      shipments ||= Shipment.includes(:tea_lot).order(:shipped_at)
      
      CSV.generate(headers: true) do |csv|
        csv << [
          '出荷ID', 'ロットコード', '産地', '品種', '出荷先', '出荷日', '数量(kg)', '収穫日'
        ]
        
        shipments.each do |shipment|
          csv << [
            shipment.id,
            shipment.tea_lot.lot_code,
            shipment.tea_lot.origin,
            shipment.tea_lot.variety,
            shipment.destination,
            shipment.shipped_at,
            shipment.quantity_kg,
            shipment.tea_lot.harvest_date
          ]
        end
      end
    end

    def validate_shipment_quantity(tea_lot, quantity)
      available = get_available_quantity(tea_lot)
      
      {
        valid: quantity <= available,
        available_quantity: available,
        requested_quantity: quantity,
        excess_amount: quantity > available ? quantity - available : 0
      }
    end

    def get_shipment_efficiency_metrics
      shipments = Shipment.includes(:tea_lot).all
      
      # Calculate time from harvest to shipment
      harvest_to_shipment_times = []
      
      shipments.each do |shipment|
        harvest_date = shipment.tea_lot.harvest_date
        shipment_date = shipment.shipped_at
        
        if harvest_date && shipment_date
          time_diff = shipment_date.to_date - harvest_date
          harvest_to_shipment_times << time_diff if time_diff >= 0
        end
      end
      
      if harvest_to_shipment_times.any?
        {
          average_days_from_harvest: (harvest_to_shipment_times.sum.to_f / harvest_to_shipment_times.size).round(1),
          min_days_from_harvest: harvest_to_shipment_times.min,
          max_days_from_harvest: harvest_to_shipment_times.max,
          sample_count: harvest_to_shipment_times.size
        }
      else
        {
          average_days_from_harvest: 0,
          min_days_from_harvest: 0,
          max_days_from_harvest: 0,
          sample_count: 0
        }
      end
    end

    def get_pending_shipments
      TeaLot.where.not(status: 'shipped')
            .includes(:shipments)
            .map do |lot|
        available_quantity = get_available_quantity(lot)
        
        {
          tea_lot: lot,
          available_quantity: available_quantity,
          total_shipped: lot.shipments.sum(:quantity_kg),
          shipment_count: lot.shipments.count,
          last_shipment_date: lot.shipments.maximum(:shipped_at)
        }
      end
    end

    def get_destination_analysis
      shipments = Shipment.includes(:tea_lot).all
      
      destination_stats = shipments.group_by(&:destination).map do |destination, dest_shipments|
        total_quantity = dest_shipments.sum(&:quantity_kg)
        unique_lots = dest_shipments.map(&:tea_lot).uniq.count
        
        {
          destination: destination,
          total_quantity: total_quantity,
          shipment_count: dest_shipments.count,
          unique_lots_count: unique_lots,
          average_quantity: (total_quantity.to_f / dest_shipments.count).round(2),
          first_shipment_date: dest_shipments.minimum(:shipped_at),
          last_shipment_date: dest_shipments.maximum(:shipped_at)
        }
      end
      
      destination_stats.sort_by { |stat| -stat[:total_quantity] }
    end

    def get_monthly_shipment_report(year = Date.current.year)
      shipments = Shipment.where("EXTRACT(YEAR FROM shipped_at) = ?", year)
                         .includes(:tea_lot)
      
      monthly_data = {}
      
      (1..12).each do |month|
        month_shipments = shipments.where("EXTRACT(MONTH FROM shipped_at) = ?", month)
        
        monthly_data[month] = {
          shipment_count: month_shipments.count,
          total_quantity: month_shipments.sum(:quantity_kg),
          unique_destinations: month_shipments.distinct.count(:destination),
          unique_lots: month_shipments.distinct.count(:tea_lot_id),
          average_quantity: month_shipments.count > 0 ? (month_shipments.sum(:quantity_kg).to_f / month_shipments.count).round(2) : 0
        }
      end
      
      monthly_data
    end

    def bulk_create_shipments(shipments_data)
      Shipment.transaction do
        created_shipments = []
        
        shipments_data.each do |shipment_data|
          tea_lot = TeaLot.find(shipment_data[:tea_lot_id])
          
          # Validate quantity before creating
          validation = validate_shipment_quantity(tea_lot, shipment_data[:quantity_kg])
          
          unless validation[:valid]
            raise ActiveRecord::RecordInvalid, "Insufficient quantity for TeaLot #{tea_lot.lot_code}"
          end
          
          shipment = tea_lot.shipments.build(shipment_data.except(:tea_lot_id))
          
          if shipment.save
            created_shipments << shipment
          else
            raise ActiveRecord::RecordInvalid, shipment
          end
        end
        
        # Update tea lot statuses
        created_shipments.each do |shipment|
          total_shipped = shipment.tea_lot.shipments.sum(:quantity_kg)
          if total_shipped >= shipment.tea_lot.quantity_kg
            shipment.tea_lot.update!(status: 'shipped')
          end
        end
        
        created_shipments
      end
    end
  end
end
