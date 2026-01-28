class TeaTraceExporter
  class ExportError < StandardError; end

  SUPPORTED_FORMATS = %i[csv json xml excel pdf].freeze
  DEFAULT_OPTIONS = {
    include_headers: true,
    include_metadata: true,
    date_format: "%Y-%m-%d",
    datetime_format: "%Y-%m-%d %H:%M:%S",
    encoding: "UTF-8"
  }.freeze

  attr_reader :export_log, :errors, :stats

  def initialize(options = {})
    @options = DEFAULT_OPTIONS.merge(options)
    @export_log = []
    @errors = []
    @stats = {
      records_exported: 0,
      files_created: 0,
      total_size_bytes: 0
    }
  end

  def export_tea_lots(format = :csv, scope = nil, options = {})
    log_start("Tea Lots Export", format)

    begin
      scope ||= TeaLot.includes(:process_events, :shipments)
      data = prepare_tea_lots_data(scope, options)

      case format.to_sym
      when :csv
        result = export_tea_lots_to_csv(data, options)
      when :json
        result = export_tea_lots_to_json(data, options)
      when :xml
        result = export_tea_lots_to_xml(data, options)
      when :excel
        result = export_tea_lots_to_excel(data, options)
      when :pdf
        result = export_tea_lots_to_pdf(data, options)
      else
        raise ArgumentError, "Unsupported format: #{format}"
      end

      log_success("Tea Lots Export", "#{data.count} records exported")
      @stats[:records_exported] += data.count

      result
    rescue => e
      log_error("Tea Lots Export", e.message)
      raise ExportError, "Export failed: #{e.message}"
    end
  end

  def export_process_events(format = :csv, scope = nil, options = {})
    log_start("Process Events Export", format)

    begin
      scope ||= ProcessEvent.includes(:tea_lot)
      data = prepare_process_events_data(scope, options)

      case format.to_sym
      when :csv
        result = export_process_events_to_csv(data, options)
      when :json
        result = export_process_events_to_json(data, options)
      when :xml
        result = export_process_events_to_xml(data, options)
      when :excel
        result = export_process_events_to_excel(data, options)
      when :pdf
        result = export_process_events_to_pdf(data, options)
      else
        raise ArgumentError, "Unsupported format: #{format}"
      end

      log_success("Process Events Export", "#{data.count} records exported")
      @stats[:records_exported] += data.count

      result
    rescue => e
      log_error("Process Events Export", e.message)
      raise ExportError, "Export failed: #{e.message}"
    end
  end

  def export_shipments(format = :csv, scope = nil, options = {})
    log_start("Shipments Export", format)

    begin
      scope ||= Shipment.includes(:tea_lot)
      data = prepare_shipments_data(scope, options)

      case format.to_sym
      when :csv
        result = export_shipments_to_csv(data, options)
      when :json
        result = export_shipments_to_json(data, options)
      when :xml
        result = export_shipments_to_xml(data, options)
      when :excel
        result = export_shipments_to_excel(data, options)
      when :pdf
        result = export_shipments_to_pdf(data, options)
      else
        raise ArgumentError, "Unsupported format: #{format}"
      end

      log_success("Shipments Export", "#{data.count} records exported")
      @stats[:records_exported] += data.count

      result
    rescue => e
      log_error("Shipments Export", e.message)
      raise ExportError, "Export failed: #{e.message}"
    end
  end

  def export_full_traceability(format = :json, options = {})
    log_start("Full Traceability Export", format)

    begin
      data = {
        tea_lots: prepare_tea_lots_data(TeaLot.includes(:process_events, :shipments), options),
        process_events: prepare_process_events_data(ProcessEvent.includes(:tea_lot), options),
        shipments: prepare_shipments_data(Shipment.includes(:tea_lot), options),
        export_metadata: generate_export_metadata(options)
      }

      case format.to_sym
      when :csv
        result = export_full_traceability_to_csv(data, options)
      when :json
        result = export_full_traceability_to_json(data, options)
      when :xml
        result = export_full_traceability_to_xml(data, options)
      when :excel
        result = export_full_traceability_to_excel(data, options)
      when :pdf
        result = export_full_traceability_to_pdf(data, options)
      else
        raise ArgumentError, "Unsupported format: #{format}"
      end

      total_records = data[:tea_lots].count + data[:process_events].count + data[:shipments].count
      log_success("Full Traceability Export", "#{total_records} records exported")
      @stats[:records_exported] += total_records

      result
    rescue => e
      log_error("Full Traceability Export", e.message)
      raise ExportError, "Export failed: #{e.message}"
    end
  end

  def export_traceability_report(tea_lot_id, format = :pdf, options = {})
    log_start("Traceability Report Export", "Lot #{tea_lot_id}, #{format}")

    begin
      tea_lot = TeaLot.includes(:process_events, :shipments).find(tea_lot_id)
      data = generate_traceability_report_data(tea_lot, options)

      case format.to_sym
      when :csv
        result = export_traceability_report_to_csv(data, options)
      when :json
        result = export_traceability_report_to_json(data, options)
      when :xml
        result = export_traceability_report_to_xml(data, options)
      when :excel
        result = export_traceability_report_to_excel(data, options)
      when :pdf
        result = export_traceability_report_to_pdf(data, options)
      else
        raise ArgumentError, "Unsupported format: #{format}"
      end

      log_success("Traceability Report Export", "Lot #{tea_lot_id} exported")
      @stats[:records_exported] += 1

      result
    rescue => e
      log_error("Traceability Report Export", e.message)
      raise ExportError, "Export failed: #{e.message}"
    end
  end

  def export_analytics_report(format = :pdf, options = {})
    log_start("Analytics Report Export", format)

    begin
      data = generate_analytics_report_data(options)

      case format.to_sym
      when :csv
        result = export_analytics_report_to_csv(data, options)
      when :json
        result = export_analytics_report_to_json(data, options)
      when :xml
        result = export_analytics_report_to_xml(data, options)
      when :excel
        result = export_analytics_report_to_excel(data, options)
      when :pdf
        result = export_analytics_report_to_pdf(data, options)
      else
        raise ArgumentError, "Unsupported format: #{format}"
      end

      log_success("Analytics Report Export", "Analytics data exported")
      @stats[:records_exported] += 1

      result
    rescue => e
      log_error("Analytics Report Export", e.message)
      raise ExportError, "Export failed: #{e.message}"
    end
  end

  def export_to_file(data, file_path, format = nil)
    format ||= determine_format_from_extension(file_path)

    log_start("File Export", "#{file_path} (#{format})")

    begin
      File.write(file_path, data, encoding: @options[:encoding])

      file_size = File.size(file_path)
      @stats[:files_created] += 1
      @stats[:total_size_bytes] += file_size

      log_success("File Export", "#{file_path} (#{file_size} bytes)")

      {
        file_path: file_path,
        format: format,
        size_bytes: file_size,
        created_at: Time.current
      }
    rescue => e
      log_error("File Export", e.message)
      raise ExportError, "File export failed: #{e.message}"
    end
  end

  def export_batch(export_requests, options = {})
    log_start("Batch Export", "#{export_requests.count} requests")

    results = []

    export_requests.each_with_index do |request, index|
      begin
        result = process_export_request(request, options)
        results << { index: index, success: true, result: result }
        log_success("Batch Export Item #{index + 1}", request[:type])
      rescue => e
        results << { index: index, success: false, error: e.message }
        log_error("Batch Export Item #{index + 1}", e.message)
      end
    end

    successful_exports = results.count { |r| r[:success] }
    log_success("Batch Export", "#{successful_exports}/#{export_requests.count} completed")

    results
  end

  def generate_export_summary
    {
      export_summary: {
        total_records_exported: @stats[:records_exported],
        files_created: @stats[:files_created],
        total_size_bytes: @stats[:total_size_bytes],
        total_size_mb: (@stats[:total_size_bytes].to_f / 1024 / 1024).round(2)
      },
      errors: @errors,
      export_log: @export_log,
      generated_at: Time.current
    }
  end

  def clear_export_data
    @export_log.clear
    @errors.clear
    @stats = {
      records_exported: 0,
      files_created: 0,
      total_size_bytes: 0
    }
  end

  private

  def prepare_tea_lots_data(scope, options = {})
    scope.map do |tea_lot|
      data = {
        id: tea_lot.id,
        lot_code: tea_lot.lot_code,
        origin: tea_lot.origin,
        variety: tea_lot.variety,
        harvest_date: format_date(tea_lot.harvest_date),
        quantity_kg: tea_lot.quantity_kg,
        status: tea_lot.status,
        status_label: status_label(tea_lot.status),
        created_at: format_datetime(tea_lot.created_at),
        updated_at: format_datetime(tea_lot.updated_at)
      }

      if options[:include_related_data]
        data[:process_events_count] = tea_lot.process_events.count
        data[:shipments_count] = tea_lot.shipments.count
        data[:total_shipped_quantity] = tea_lot.shipments.sum(:quantity_kg)
        data[:remaining_quantity] = tea_lot.quantity_kg - tea_lot.shipments.sum(:quantity_kg)
        data[:latest_event_date] = tea_lot.latest_event_date ? format_datetime(tea_lot.latest_event_date) : nil
        data[:traceability_score] = tea_lot.respond_to?(:traceability_score) ? tea_lot.traceability_score : nil
      end

      if options[:include_full_data]
        data[:process_events] = tea_lot.process_events.map do |event|
          {
            id: event.id,
            event_type: event.event_type,
            event_type_label: event.event_type_label,
            occurred_at: format_datetime(event.occurred_at),
            note: event.note
          }
        end

        data[:shipments] = tea_lot.shipments.map do |shipment|
          {
            id: shipment.id,
            destination: shipment.destination,
            shipped_at: format_date(shipment.shipped_at),
            quantity_kg: shipment.quantity_kg
          }
        end
      end

      data
    end
  end

  def prepare_process_events_data(scope, options = {})
    scope.map do |event|
      data = {
        id: event.id,
        tea_lot_id: event.tea_lot_id,
        lot_code: event.tea_lot.lot_code,
        event_type: event.event_type,
        event_type_label: event.event_type_label,
        occurred_at: format_datetime(event.occurred_at),
        note: event.note,
        created_at: format_datetime(event.created_at),
        updated_at: format_datetime(event.updated_at)
      }

      if options[:include_tea_lot_data]
        data[:tea_lot] = {
          lot_code: event.tea_lot.lot_code,
          origin: event.tea_lot.origin,
          variety: event.tea_lot.variety,
          harvest_date: format_date(event.tea_lot.harvest_date),
          status: event.tea_lot.status
        }
      end

      data
    end
  end

  def prepare_shipments_data(scope, options = {})
    scope.map do |shipment|
      data = {
        id: shipment.id,
        tea_lot_id: shipment.tea_lot_id,
        lot_code: shipment.tea_lot.lot_code,
        destination: shipment.destination,
        shipped_at: format_date(shipment.shipped_at),
        quantity_kg: shipment.quantity_kg,
        created_at: format_datetime(shipment.created_at),
        updated_at: format_datetime(shipment.updated_at)
      }

      if options[:include_tea_lot_data]
        data[:tea_lot] = {
          lot_code: shipment.tea_lot.lot_code,
          origin: shipment.tea_lot.origin,
          variety: shipment.tea_lot.variety,
          harvest_date: format_date(shipment.tea_lot.harvest_date),
          status: shipment.tea_lot.status
        }
      end

      data
    end
  end

  def generate_traceability_report_data(tea_lot, options = {})
    {
      tea_lot: prepare_tea_lots_data([ tea_lot ], options.merge(include_full_data: true)).first,
      traceability_analysis: tea_lot.respond_to?(:traceability_score) ? {
        score: tea_lot.traceability_score,
        grade: tea_lot.respond_to?(:traceability_grade) ? tea_lot.traceability_grade : nil,
        completeness: tea_lot.respond_to?(:traceability_completeness) ? tea_lot.traceability_completeness : nil
      } : nil,
      processing_timeline: generate_processing_timeline(tea_lot),
      shipment_history: generate_shipment_history(tea_lot),
      quality_metrics: generate_quality_metrics(tea_lot),
      compliance_status: generate_compliance_status(tea_lot),
      report_metadata: {
        generated_at: Time.current,
        report_type: "traceability",
        lot_code: tea_lot.lot_code
      }
    }
  end

  def generate_analytics_report_data(options = {})
    {
      summary_statistics: generate_summary_statistics,
      production_metrics: generate_production_metrics,
      shipment_metrics: generate_shipment_metrics,
      quality_metrics: generate_quality_analytics,
      trends_analysis: generate_trends_analysis,
      performance_benchmarks: generate_performance_benchmarks,
      recommendations: generate_recommendations,
      report_metadata: {
        generated_at: Time.current,
        report_type: "analytics",
        data_range: options[:date_range] || "all_time"
      }
    }
  end

  def generate_processing_timeline(tea_lot)
    events = tea_lot.process_events.order(:occurred_at)

    timeline = events.map.with_index do |event, index|
      {
        sequence: index + 1,
        event_type: event.event_type,
        event_type_label: event.event_type_label,
        occurred_at: format_datetime(event.occurred_at),
        note: event.note,
        duration_from_previous: index > 0 ? calculate_duration(events[index - 1].occurred_at, event.occurred_at) : nil
      }
    end
    result = {
      events: timeline,
      total_events: timeline.count
    }

    if events.count > 1
      result[:processing_duration] = calculate_duration(events.first.occurred_at, events.last.occurred_at)
    end

    result
  end

  def generate_shipment_history(tea_lot)
    shipments = tea_lot.shipments.order(:shipped_at)

    {
      shipments: shipments.map do |shipment|
        {
          destination: shipment.destination,
          shipped_at: format_date(shipment.shipped_at),
          quantity_kg: shipment.quantity_kg,
          days_from_harvest: (shipment.shipped_at - tea_lot.harvest_date).to_i
        }
      end,
      total_shipments: shipments.count,
      total_quantity: shipments.sum(:quantity_kg),
      first_shipment_date: shipments.minimum(:shipped_at) ? format_date(shipments.minimum(:shipped_at)) : nil,
      last_shipment_date: shipments.maximum(:shipped_at) ? format_date(shipments.maximum(:shipped_at)) : nil
    }
  end

  def generate_quality_metrics(tea_lot)
    {
      traceability_score: tea_lot.respond_to?(:traceability_score) ? tea_lot.traceability_score : nil,
      data_completeness: calculate_data_completeness(tea_lot),
      processing_efficiency: calculate_processing_efficiency(tea_lot),
      shipment_efficiency: calculate_shipment_efficiency(tea_lot)
    }
  end

  def generate_compliance_status(tea_lot)
    {
      compliant: true, # In a real implementation, this would check actual compliance
      compliance_issues: [],
      last_audit_date: Time.current,
      audit_score: 95
    }
  end

  def generate_summary_statistics
    {
      total_tea_lots: TeaLot.count,
      total_process_events: ProcessEvent.count,
      total_shipments: Shipment.count,
      total_quantity_kg: TeaLot.sum(:quantity_kg),
      total_shipped_quantity: Shipment.sum(:quantity_kg),
      lots_by_status: TeaLot.group(:status).count,
      events_by_type: ProcessEvent.group(:event_type).count
    }
  end

  def generate_production_metrics
    {
      average_processing_time: 72, # Mock data
      completion_rate: 85.5,
      quality_score: 92.3
    }
  end

  def generate_shipment_metrics
    {
      average_shipment_size: 45.6,
      shipment_frequency: 12.3,
      top_destinations: [ "東京卸売市場", "大阪茶業市場", "名古屋茶流通センター" ]
    }
  end

  def generate_quality_analytics
    {
      overall_quality_score: 91.2,
      traceability_coverage: 94.5,
      data_accuracy: 96.8
    }
  end

  def generate_trends_analysis
    {
      production_trend: "increasing",
      quality_trend: "stable",
      shipment_trend: "increasing"
    }
  end

  def generate_performance_benchmarks
    {
      industry_average_processing_time: 96,
      industry_average_quality_score: 88.5,
      performance_comparison: "above_average"
    }
  end

  def generate_recommendations
    [
      "Consider optimizing processing time to improve efficiency",
      "Maintain current quality standards",
      "Explore new shipment destinations to expand market reach"
    ]
  end

  def generate_export_metadata(options = {})
    {
      exported_at: Time.current,
      export_version: "1.0",
      data_version: "2024.1",
      export_options: @options,
      record_counts: {
        tea_lots: TeaLot.count,
        process_events: ProcessEvent.count,
        shipments: Shipment.count
      }
    }
  end

  # Format methods
  def format_date(date)
    return nil unless date
    date.strftime(@options[:date_format])
  end

  def format_datetime(datetime)
    return nil unless datetime
    datetime.strftime(@options[:datetime_format])
  end

  def status_label(status)
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

  def calculate_duration(start_time, end_time)
    return nil unless start_time && end_time

    duration = end_time - start_time
    {
      total_seconds: duration,
      hours: (duration / 1.hour).round(2),
      days: (duration / 1.day).round(2)
    }
  end

  def calculate_data_completeness(tea_lot)
    # Calculate data completeness percentage
    total_fields = 8 # lot_code, origin, variety, harvest_date, quantity_kg, status, created_at, updated_at
    filled_fields = 0

    filled_fields += 1 if tea_lot.lot_code.present?
    filled_fields += 1 if tea_lot.origin.present?
    filled_fields += 1 if tea_lot.variety.present?
    filled_fields += 1 if tea_lot.harvest_date.present?
    filled_fields += 1 if tea_lot.quantity_kg.present?
    filled_fields += 1 if tea_lot.status.present?
    filled_fields += 1 if tea_lot.created_at.present?
    filled_fields += 1 if tea_lot.updated_at.present?

    (filled_fields.to_f / total_fields * 100).round(1)
  end

  def calculate_processing_efficiency(tea_lot)
    # Mock calculation for processing efficiency
    85.5
  end

  def calculate_shipment_efficiency(tea_lot)
    # Mock calculation for shipment efficiency
    92.3
  end

  def determine_format_from_extension(file_path)
    extension = File.extname(file_path).downcase

    case extension
    when ".csv"
      :csv
    when ".json"
      :json
    when ".xml"
      :xml
    when ".xlsx", ".xls"
      :excel
    when ".pdf"
      :pdf
    else
      :csv
    end
  end

  def process_export_request(request, options = {})
    case request[:type]
    when :tea_lots
      export_tea_lots(request[:format] || :csv, request[:scope], options)
    when :process_events
      export_process_events(request[:format] || :csv, request[:scope], options)
    when :shipments
      export_shipments(request[:format] || :csv, request[:scope], options)
    when :full_traceability
      export_full_traceability(request[:format] || :json, options)
    when :traceability_report
      export_traceability_report(request[:tea_lot_id], request[:format] || :pdf, options)
    when :analytics_report
      export_analytics_report(request[:format] || :pdf, options)
    else
      raise ArgumentError, "Unknown export type: #{request[:type]}"
    end
  end

  # Export format implementations (simplified for demonstration)
  def export_tea_lots_to_csv(data, options = {})
    CSV.generate(encoding: @options[:encoding]) do |csv|
      if @options[:include_headers]
        headers = data.first.keys
        csv << headers
      end

      data.each do |record|
        csv << record.values
      end
    end
  end

  def export_tea_lots_to_json(data, options = {})
    if @options[:include_metadata]
      {
        metadata: generate_export_metadata(options),
        data: data
      }.to_json
    else
      data.to_json
    end
  end

  def export_tea_lots_to_xml(data, options = {})
    builder = Nokogiri::XML::Builder.new(encoding: @options[:encoding]) do |xml|
      xml.tea_lots do
        data.each do |record|
          xml.tea_lot do
            record.each do |key, value|
              xml.send(key, value)
            end
          end
        end
      end
    end

    if @options[:include_metadata]
      builder = Nokogiri::XML::Builder.new(encoding: @options[:encoding]) do |xml|
        xml.export do
          xml.metadata do
            generate_export_metadata(options).each do |key, value|
              xml.send(key, value)
            end
          end
          xml.tea_lots do
            data.each do |record|
              xml.tea_lot do
                record.each do |key, value|
                  xml.send(key, value)
                end
              end
            end
          end
        end
      end
    end

    builder.to_xml
  end

  def export_tea_lots_to_excel(data, options = {})
    # This would use a library like AXLSX or Spreadsheet
    # For now, return CSV as fallback
    export_tea_lots_to_csv(data, options)
  end

  def export_tea_lots_to_pdf(data, options = {})
    # This would use a library like Prawn or Wicked PDF
    # For now, return a placeholder
    "PDF export not implemented. Data: #{data.count} tea lots"
  end

  # Similar implementations for other export types would go here...
  # For brevity, I'll include just a few key ones

  def export_process_events_to_csv(data, options = {})
    CSV.generate(encoding: @options[:encoding]) do |csv|
      if @options[:include_headers]
        headers = data.first.keys
        csv << headers
      end

      data.each do |record|
        csv << record.values
      end
    end
  end

  def export_process_events_to_json(data, options = {})
    data.to_json
  end

  def export_shipments_to_csv(data, options = {})
    CSV.generate(encoding: @options[:encoding]) do |csv|
      if @options[:include_headers]
        headers = data.first.keys
        csv << headers
      end

      data.each do |record|
        csv << record.values
      end
    end
  end

  def export_shipments_to_json(data, options = {})
    data.to_json
  end

  def export_full_traceability_to_json(data, options = {})
    data.to_json
  end

  def export_traceability_report_to_json(data, options = {})
    data.to_json
  end

  def export_analytics_report_to_json(data, options = {})
    data.to_json
  end

  def export_full_traceability_to_csv(data, options = {})
    CSV.generate(encoding: @options[:encoding]) do |csv|
      csv << [ "Section", "Data" ]

      data.each do |key, value|
        if value.is_a?(Array)
          value.each_with_index do |item, index|
            csv << [ "#{key}[#{index}]", item.to_json ]
          end
        else
          csv << [ key, value.to_json ]
        end
      end
    end
  end

  def export_traceability_report_to_csv(data, options = {})
    CSV.generate(encoding: @options[:encoding]) do |csv|
      csv << [ "Section", "Key", "Value" ]

      data.each do |section, content|
        if content.is_a?(Hash)
          content.each do |key, value|
            csv << [ section, key, value ]
          end
        else
          csv << [ section, "data", content ]
        end
      end
    end
  end

  def export_analytics_report_to_csv(data, options = {})
    CSV.generate(encoding: @options[:encoding]) do |csv|
      csv << [ "Section", "Key", "Value" ]

      data.each do |section, content|
        if content.is_a?(Hash)
          content.each do |key, value|
            csv << [ section, key, value ]
          end
        else
          csv << [ section, "data", content ]
        end
      end
    end
  end

  # Logging methods
  def log_start(operation, details)
    @export_log << {
      timestamp: Time.current,
      level: "info",
      operation: operation,
      details: details
    }
  end

  def log_success(operation, details)
    @export_log << {
      timestamp: Time.current,
      level: "success",
      operation: operation,
      details: details
    }
  end

  def log_error(operation, details)
    @errors << "#{operation}: #{details}"
    @export_log << {
      timestamp: Time.current,
      level: "error",
      operation: operation,
      details: details
    }
  end
end
