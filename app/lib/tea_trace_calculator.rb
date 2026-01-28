module TeaTraceCalculator
  extend ActiveSupport::Concern

  class_methods do
    def calculate_lot_efficiency(tea_lot)
      events = tea_lot.process_events.order(:occurred_at)
      return nil if events.count < 2

      first_event = events.first
      last_event = events.last

      total_time = last_event.occurred_at - first_event.occurred_at
      harvest_to_first = first_event.occurred_at - tea_lot.harvest_date.to_time

      {
        total_processing_time_hours: (total_time / 1.hour).round(2),
        harvest_to_first_event_hours: (harvest_to_first / 1.hour).round(2),
        events_completed: events.count,
        required_events: %w[steaming rolling drying packing].length,
        completion_percentage: ((events.count.to_f / 4) * 100).round(1),
        average_time_between_events: (total_time / (events.count - 1) / 1.hour).round(2)
      }
    end

    def calculate_shipment_efficiency(tea_lot)
      shipments = tea_lot.shipments.order(:shipped_at)
      return nil if shipments.empty?

      first_shipment = shipments.first
      harvest_to_shipment = first_shipment.shipped_at - tea_lot.harvest_date

      {
        days_from_harvest_to_first_shipment: harvest_to_shipment.to_i,
        total_shipments: shipments.count,
        total_shipped_quantity: shipments.sum(:quantity_kg),
        shipment_rate: (shipments.sum(:quantity_kg).to_f / tea_lot.quantity_kg * 100).round(1),
        average_shipment_size: (shipments.sum(:quantity_kg).to_f / shipments.count).round(2)
      }
    end

    def calculate_quality_metrics(tea_lot)
      events = tea_lot.process_events

      # Calculate time gaps between events
      event_gaps = []
      sorted_events = events.order(:occurred_at)

      sorted_events.each_cons(2) do |prev_event, curr_event|
        gap = curr_event.occurred_at - prev_event.occurred_at
        event_gaps << gap
      end

      # Quality score based on processing consistency
      quality_factors = {
        event_consistency: calculate_event_consistency(events),
        timing_optimization: calculate_timing_optimization(event_gaps),
        completeness_score: calculate_completeness_score(events)
      }

      overall_score = (quality_factors.values.sum / quality_factors.count * 100).round(1)

      quality_factors.merge(overall_quality_score: overall_score)
    end

    def calculate_inventory_metrics
      total_lots = TeaLot.count
      lots_by_status = TeaLot.group(:status).count

      total_quantity = TeaLot.sum(:quantity_kg)
      shipped_quantity = Shipment.sum(:quantity_kg)
      available_quantity = total_quantity - shipped_quantity

      inventory_turnover = calculate_inventory_turnover

      {
        total_lots: total_lots,
        lots_by_status: lots_by_status,
        total_quantity_kg: total_quantity,
        shipped_quantity_kg: shipped_quantity,
        available_quantity_kg: available_quantity,
        shipment_rate: (shipped_quantity.to_f / total_quantity * 100).round(1),
        inventory_turnover_days: inventory_turnover,
        average_lot_size: (total_quantity.to_f / total_lots).round(2)
      }
    end

    def calculate_production_metrics(date_range = nil)
      events = ProcessEvent.all
      events = events.where(occurred_at: date_range) if date_range

      events_by_type = events.group(:event_type).count
      events_by_day = events.group_by_day(:occurred_at).count

      # Calculate production efficiency
      completed_lots = TeaLot.joins(:process_events)
                            .where(process_events: { event_type: "packing" })
                            .distinct
                            .count

      processing_lots = TeaLot.joins(:process_events)
                             .where(process_events: { event_type: [ "steaming", "rolling", "drying" ] })
                             .where.not(status: "shipped")
                             .distinct
                             .count

      {
        total_events: events.count,
        events_by_type: events_by_type,
        events_by_day: events_by_day,
        completed_lots: completed_lots,
        processing_lots: processing_lots,
        completion_rate: TeaLot.count > 0 ? (completed_lots.to_f / TeaLot.count * 100).round(1) : 0,
        average_events_per_day: events_by_day.values.sum.to_f / events_by_day.count.round(2)
      }
    end

    def calculate_financial_metrics
      # Estimated values (in a real app, these would come from actual financial data)
      price_per_kg_by_variety = {
        "やぶきた" => 2000,
        "さやまかおり" => 1800,
        "玉露" => 5000,
        "ほうじ茶" => 1500,
        "煎茶" => 2200,
        "かぶせ" => 3000,
        "抹茶" => 8000,
        "番茶" => 1200
      }

      total_value = 0
      shipped_value = 0

      TeaLot.includes(:shipments).find_each do |lot|
        lot_value = lot.quantity_kg * (price_per_kg_by_variety[lot.variety] || 2000)
        total_value += lot_value

        shipped_quantity = lot.shipments.sum(:quantity_kg)
        shipped_value += shipped_quantity * (price_per_kg_by_variety[lot.variety] || 2000)
      end

      {
        total_inventory_value: total_value,
        shipped_value: shipped_value,
        remaining_value: total_value - shipped_value,
        value_per_kg_average: TeaLot.sum(:quantity_kg) > 0 ? (total_value.to_f / TeaLot.sum(:quantity_kg)).round(0) : 0
      }
    end

    def calculate_seasonal_trends
      current_year = Date.current.year
      lots_by_month = TeaLot.where("EXTRACT(YEAR FROM harvest_date) = ?", current_year)
                           .group_by_month(:harvest_date)
                           .count

      shipments_by_month = Shipment.where("EXTRACT(YEAR FROM shipped_at) = ?", current_year)
                                  .group_by_month(:shipped_at)
                                  .sum(:quantity_kg)

      # Fill missing months with 0
      (1..12).each do |month|
        lots_by_month[month] ||= 0
        shipments_by_month[month] ||= 0
      end

      {
        harvest_trends: lots_by_month.sort.to_h,
        shipment_trends: shipments_by_month.sort.to_h,
        peak_harvest_month: lots_by_months.max_by { |_, count| count }&.first,
        peak_shipment_month: shipments_by_month.max_by { |_, quantity| quantity }&.first
      }
    end

    def calculate_performance_benchmarks
      lots = TeaLot.includes(:process_events, :shipments).all

      processing_times = lots.map { |lot| calculate_lot_efficiency(lot) }.compact
      shipment_times = lots.map { |lot| calculate_shipment_efficiency(lot) }.compact

      {
        average_processing_time_hours: processing_times.empty? ? 0 : (processing_times.map { |p| p[:total_processing_time_hours] }.sum / processing_times.count).round(2),
        fastest_processing_time_hours: processing_times.empty? ? 0 : processing_times.map { |p| p[:total_processing_time_hours] }.min.round(2),
        slowest_processing_time_hours: processing_times.empty? ? 0 : processing_times.map { |p| p[:total_processing_time_hours] }.max.round(2),
        average_harvest_to_shipment_days: shipment_times.empty? ? 0 : (shipment_times.map { |s| s[:days_from_harvest_to_first_shipment] }.sum / shipment_times.count).round(1),
        fastest_shipment_days: shipment_times.empty? ? 0 : shipment_times.map { |s| s[:days_from_harvest_to_first_shipment] }.min,
        slowest_shipment_days: shipment_times.empty? ? 0 : shipment_times.map { |s| s[:days_from_harvest_to_first_shipment] }.max
      }
    end

    def calculate_traceability_score(tea_lot)
      events = tea_lot.process_events
      shipments = tea_lot.shipments

      # Factors affecting traceability
      event_completeness = (events.count.to_f / 4 * 100).round(1) # 4 required events
      shipment_tracking = shipments.count > 0 ? 100 : 0
      data_quality = calculate_data_quality(events, shipments)

      # Weight the factors
      weights = { event_completeness: 0.4, shipment_tracking: 0.3, data_quality: 0.3 }

      weighted_score = (
        event_completeness * weights[:event_completeness] +
        shipment_tracking * weights[:shipment_tracking] +
        data_quality * weights[:data_quality]
      ).round(1)

      {
        traceability_score: weighted_score,
        event_completeness: event_completeness,
        shipment_tracking: shipment_tracking,
        data_quality: data_quality,
        grade: get_traceability_grade(weighted_score)
      }
    end

    private

    def calculate_event_consistency(events)
      return 0 if events.count < 2

      # Calculate variance in time between events
      event_times = events.order(:occurred_at).pluck(:occurred_at)
      intervals = []

      event_times.each_cons(2) do |prev, curr|
        intervals << (curr - prev) / 1.hour
      end

      # Lower variance = higher consistency
      mean = intervals.sum.to_f / intervals.count
      variance = intervals.sum { |interval| (interval - mean) ** 2 } / intervals.count
      standard_deviation = Math.sqrt(variance)

      # Normalize to 0-100 scale (lower std dev = higher score)
      [ 100 - (standard_deviation * 10), 0 ].max.round(1)
    end

    def calculate_timing_optimization(event_gaps)
      return 0 if event_gaps.empty?

      # Ideal processing times (in hours)
      ideal_gaps = {
        "steaming_to_rolling" => 2,
        "rolling_to_drying" => 3,
        "drying_to_packing" => 4
      }

      # Calculate deviation from ideal
      total_deviation = 0
      ideal_gaps.values.each { |ideal| total_deviation += ideal }

      actual_total = event_gaps.sum / 1.hour
      deviation_percentage = [ (actual_total - total_deviation) / total_deviation * 100, 0 ].max

      # Convert to score (lower deviation = higher score)
      [ 100 - deviation_percentage, 0 ].max.round(1)
    end

    def calculate_completeness_score(events)
      required_events = %w[steaming rolling drying packing]
      completed_events = events.pluck(:event_type) & required_events

      (completed_events.length.to_f / required_events.length * 100).round(1)
    end

    def calculate_inventory_turnover
      # Simple calculation: average days inventory is held
      shipped_lots = TeaLot.joins(:shipments).distinct

      return 0 if shipped_lots.empty?

      total_days = shipped_lots.sum do |lot|
        first_shipment = lot.shipments.minimum(:shipped_at)
        (first_shipment - lot.harvest_date).to_i if first_shipment && lot.harvest_date
      end

      (total_days.to_f / shipped_lots.count).round(1)
    end

    def calculate_data_quality(events, shipments)
      # Check for missing or incomplete data
      issues = 0
      total_checks = 0

      # Check events
      events.each do |event|
        total_checks += 2 # note and occurred_at
        issues += 1 if event.note.blank?
        issues += 1 if event.occurred_at.blank?
      end

      # Check shipments
      shipments.each do |shipment|
        total_checks += 2 # destination and shipped_at
        issues += 1 if shipment.destination.blank?
        issues += 1 if shipment.shipped_at.blank?
      end

      return 100 if total_checks == 0

      ((total_checks - issues).to_f / total_checks * 100).round(1)
    end

    def get_traceability_grade(score)
      case score
      when 90..100
        "A+"
      when 80..89
        "A"
      when 70..79
        "B"
      when 60..69
        "C"
      when 50..59
        "D"
      else
        "F"
      end
    end
  end
end
