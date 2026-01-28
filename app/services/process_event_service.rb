class ProcessEventService
  class << self
    def create_event(tea_lot, event_params)
      ProcessEvent.transaction do
        event = tea_lot.process_events.build(event_params)

        # Set default occurred_at if not provided
        event.occurred_at ||= Time.current

        if event.save
          # Update tea lot status
          TeaLotService.update_status_based_on_events(tea_lot)

          # Log the event creation
          Rails.logger.info "ProcessEvent created: #{event.id} for TeaLot: #{tea_lot.lot_code}"

          event
        else
          raise ActiveRecord::RecordInvalid, event
        end
      end
    end

    def bulk_create_events(tea_lot, events_data)
      ProcessEvent.transaction do
        created_events = []

        events_data.each do |event_data|
          event = tea_lot.process_events.build(event_data)
          event.occurred_at ||= Time.current

          if event.save
            created_events << event
          else
            raise ActiveRecord::RecordInvalid, event
          end
        end

        # Update tea lot status after all events are created
        TeaLotService.update_status_based_on_events(tea_lot)

        created_events
      end
    end

    def get_events_by_type(event_type)
      ProcessEvent.where(event_type: event_type)
                  .includes(:tea_lot)
                  .order(occurred_at: :desc)
    end

    def get_events_in_date_range(start_date, end_date)
      ProcessEvent.where(occurred_at: start_date..end_date)
                  .includes(:tea_lot)
                  .order(occurred_at: :desc)
    end

    def get_event_statistics
      events_by_type = ProcessEvent.group(:event_type).count
      events_by_date = ProcessEvent.group_by_day(:occurred_at).count
      total_events = ProcessEvent.count

      {
        total_events: total_events,
        events_by_type: events_by_type,
        events_by_date: events_by_date,
        average_events_per_lot: TeaLot.count > 0 ? (total_events.to_f / TeaLot.count).round(2) : 0
      }
    end

    def validate_event_sequence(tea_lot, new_event_type)
      existing_events = tea_lot.process_events.order(:occurred_at).pluck(:event_type)

      # Define expected sequence
      expected_sequence = %w[steaming rolling drying packing]

      # Find the position of the new event in the expected sequence
      new_event_position = expected_sequence.index(new_event_type)

      return false unless new_event_position

      # Check if all previous events in the sequence exist
      if new_event_position > 0
        required_events = expected_sequence[0...new_event_position]
        required_events.each do |required_event|
          return false unless existing_events.include?(required_event)
        end
      end

      # Check if the event hasn't been completed already
      !existing_events.include?(new_event_type)
    end

    def get_processing_duration(tea_lot)
      events = tea_lot.process_events.order(:occurred_at)

      return nil if events.count < 2

      first_event = events.first
      last_event = events.last

      duration = last_event.occurred_at - first_event.occurred_at

      {
        duration_seconds: duration,
        duration_hours: (duration / 1.hour).round(2),
        duration_days: (duration / 1.day).round(2),
        start_time: first_event.occurred_at,
        end_time: last_event.occurred_at,
        total_events: events.count
      }
    end

    def get_event_timeline(tea_lot)
      events = tea_lot.process_events.order(:occurred_at)

      timeline = []
      previous_event = nil

      events.each_with_index do |event, index|
        event_data = {
          id: event.id,
          event_type: event.event_type,
          event_type_label: event.event_type_label,
          occurred_at: event.occurred_at,
          note: event.note,
          sequence_number: index + 1
        }

        if previous_event
          time_diff = event.occurred_at - previous_event.occurred_at
          event_data[:time_since_previous] = {
            seconds: time_diff,
            minutes: (time_diff / 1.minute).round(2),
            hours: (time_diff / 1.hour).round(2)
          }
        end

        timeline << event_data
        previous_event = event
      end

      timeline
    end

    def export_events_to_csv(events = nil)
      events ||= ProcessEvent.includes(:tea_lot).order(:occurred_at)

      CSV.generate(headers: true) do |csv|
        csv << [
          "イベントID", "ロットコード", "産地", "イベント種別", "発生日時", "備考"
        ]

        events.each do |event|
          csv << [
            event.id,
            event.tea_lot.lot_code,
            event.tea_lot.origin,
            event.event_type_label,
            event.occurred_at,
            event.note
          ]
        end
      end
    end

    def find_delayed_lots(hours_threshold = 24)
      lots_with_recent_events = TeaLot.joins(:process_events)
                                    .where("process_events.occurred_at > ?", hours_threshold.hours.ago)
                                    .distinct

      all_lots = TeaLot.where(status: "processing")

      delayed_lots = all_lots - lots_with_recent_events

      delayed_lots.map do |lot|
        last_event = lot.process_events.order(occurred_at: :desc).first
        hours_since_last_event = last_event ? ((Time.current - last_event.occurred_at) / 1.hour).round(2) : nil

        {
          tea_lot: lot,
          last_event: last_event,
          hours_since_last_event: hours_since_last_event,
          next_expected_event: TeaLotService.get_next_expected_event(lot)
        }
      end
    end

    def get_event_efficiency_metrics
      events = ProcessEvent.includes(:tea_lot).all

      # Calculate average time between different event types
      metrics = {}

      event_types = %w[steaming rolling drying packing]

      event_types.each_cons(2) do |from_type, to_type|
        durations = []

        TeaLot.find_each do |lot|
          from_event = lot.process_events.find_by(event_type: from_type)
          to_event = lot.process_events.find_by(event_type: to_type)

          if from_event && to_event
            duration = to_event.occurred_at - from_event.occurred_at
            durations << duration if duration >= 0
          end
        end

        if durations.any?
          metrics["#{from_type}_to_#{to_type}"] = {
            average_hours: (durations.sum / durations.size / 1.hour).round(2),
            min_hours: (durations.min / 1.hour).round(2),
            max_hours: (durations.max / 1.hour).round(2),
            sample_count: durations.size
          }
        end
      end

      metrics
    end
  end
end
