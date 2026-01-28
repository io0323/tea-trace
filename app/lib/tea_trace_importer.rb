class TeaTraceImporter
  class ImportError < StandardError; end
  class ValidationError < StandardError; end

  attr_reader :import_log, :errors, :warnings, :stats

  def initialize
    @import_log = []
    @errors = []
    @warnings = []
    @stats = {
      tea_lots: { created: 0, updated: 0, failed: 0 },
      process_events: { created: 0, updated: 0, failed: 0 },
      shipments: { created: 0, updated: 0, failed: 0 }
    }
  end

  def import_from_csv(file_path, options = {})
    log_start("CSV Import", file_path)

    begin
      data = read_csv_file(file_path)
      process_import_data(data, options)
      log_completion
    rescue => e
      log_error("Import failed", e.message)
      raise ImportError, "Import failed: #{e.message}"
    end
  end

  def import_from_json(file_path, options = {})
    log_start("JSON Import", file_path)

    begin
      data = read_json_file(file_path)
      process_import_data(data, options)
      log_completion
    rescue => e
      log_error("Import failed", e.message)
      raise ImportError, "Import failed: #{e.message}"
    end
  end

  def import_from_excel(file_path, options = {})
    log_start("Excel Import", file_path)

    begin
      data = read_excel_file(file_path)
      process_import_data(data, options)
      log_completion
    rescue => e
      log_error("Import failed", e.message)
      raise ImportError, "Import failed: #{e.message}"
    end
  end

  def import_from_xml(file_path, options = {})
    log_start("XML Import", file_path)

    begin
      data = read_xml_file(file_path)
      process_import_data(data, options)
      log_completion
    rescue => e
      log_error("Import failed", e.message)
      raise ImportError, "Import failed: #{e.message}"
    end
  end

  def validate_import_data(data, options = {})
    validation_errors = []
    validation_warnings = []

    case data
    when Array
      data.each_with_index do |record, index|
        record_errors = validate_single_record(record, options)
        validation_errors.concat(record_errors.map { |error| "Row #{index + 1}: #{error}" })
      end
    when Hash
      if data.key?("tea_lots")
        data["tea_lots"].each_with_index do |record, index|
          record_errors = validate_tea_lot_record(record)
          validation_errors.concat(record_errors.map { |error| "Tea Lot #{index + 1}: #{error}" })
        end
      end

      if data.key?("process_events")
        data["process_events"].each_with_index do |record, index|
          record_errors = validate_process_event_record(record)
          validation_errors.concat(record_errors.map { |error| "Process Event #{index + 1}: #{error}" })
        end
      end

      if data.key?("shipments")
        data["shipments"].each_with_index do |record, index|
          record_errors = validate_shipment_record(record)
          validation_errors.concat(record_errors.map { |error| "Shipment #{index + 1}: #{error}" })
        end
      end
    end

    {
      valid: validation_errors.empty?,
      errors: validation_errors,
      warnings: validation_warnings
    }
  end

  def preview_import(file_path, limit = 5)
    begin
      case File.extname(file_path).downcase
      when ".csv"
        data = read_csv_file(file_path)
      when ".json"
        data = read_json_file(file_path)
      when ".xlsx", ".xls"
        data = read_excel_file(file_path)
      when ".xml"
        data = read_xml_file(file_path)
      else
        raise ImportError, "Unsupported file format: #{File.extname(file_path)}"
      end

      preview_data = data.is_a?(Array) ? data.first(limit) : data

      {
        total_records: data.is_a?(Array) ? data.count : count_nested_records(data),
        preview_data: preview_data,
        file_info: {
          path: file_path,
          size: File.size(file_path),
          modified_at: File.mtime(file_path)
        }
      }
    rescue => e
      { error: e.message }
    end
  end

  def export_template(format = :csv)
    case format.to_sym
    when :csv
      export_csv_template
    when :json
      export_json_template
    when :excel
      export_excel_template
    else
      raise ArgumentError, "Unsupported template format: #{format}"
    end
  end

  def bulk_import_tea_lots(lots_data, options = {})
    log_start("Bulk Tea Lots Import", "#{lots_data.count} records")

    TeaLot.transaction do
      lots_data.each_with_index do |lot_data, index|
        begin
          import_single_tea_lot(lot_data, options)
          log_success("Tea Lot #{index + 1}", lot_data[:lot_code] || "Unknown")
        rescue => e
          log_error("Tea Lot #{index + 1}", e.message)
          @stats[:tea_lots][:failed] += 1
          raise options[:raise_on_error] ? e : nil
        end
      end
    end

    log_completion
  end

  def bulk_import_process_events(events_data, options = {})
    log_start("Bulk Process Events Import", "#{events_data.count} records")

    ProcessEvent.transaction do
      events_data.each_with_index do |event_data, index|
        begin
          import_single_process_event(event_data, options)
          log_success("Process Event #{index + 1}", "ID: #{event_data[:id] || 'Unknown'}")
        rescue => e
          log_error("Process Event #{index + 1}", e.message)
          @stats[:process_events][:failed] += 1
          raise options[:raise_on_error] ? e : nil
        end
      end
    end

    log_completion
  end

  def bulk_import_shipments(shipments_data, options = {})
    log_start("Bulk Shipments Import", "#{shipments_data.count} records")

    Shipment.transaction do
      shipments_data.each_with_index do |shipment_data, index|
        begin
          import_single_shipment(shipment_data, options)
          log_success("Shipment #{index + 1}", "Destination: #{shipment_data[:destination] || 'Unknown'}")
        rescue => e
          log_error("Shipment #{index + 1}", e.message)
          @stats[:shipments][:failed] += 1
          raise options[:raise_on_error] ? e : nil
        end
      end
    end

    log_completion
  end

  def generate_import_report
    {
      import_summary: {
        total_records: @stats.values.map { |s| s[:created] + s[:updated] + s[:failed] }.sum,
        successful_records: @stats.values.map { |s| s[:created] + s[:updated] }.sum,
        failed_records: @stats.values.map { |s| s[:failed] }.sum,
        success_rate: calculate_success_rate
      },
      detailed_stats: @stats,
      errors: @errors,
      warnings: @warnings,
      import_log: @import_log,
      generated_at: Time.current
    }
  end

  def clear_import_data
    @import_log.clear
    @errors.clear
    @warnings.clear
    @stats = {
      tea_lots: { created: 0, updated: 0, failed: 0 },
      process_events: { created: 0, updated: 0, failed: 0 },
      shipments: { created: 0, updated: 0, failed: 0 }
    }
  end

  private

  def read_csv_file(file_path)
    require "csv"

    data = []
    headers = nil

    CSV.foreach(file_path, headers: true, encoding: "UTF-8") do |row|
      if headers.nil?
        headers = row.headers
      end

      data << row.to_h
    end

    data
  end

  def read_json_file(file_path)
    require "json"

    JSON.parse(File.read(file_path, encoding: "UTF-8"))
  end

  def read_excel_file(file_path)
    require "roo"

    spreadsheet = Roo::Spreadsheet.open(file_path)
    data = []

    spreadsheet.each_with_index do |row, index|
      next if index == 0 # Skip header row

      # Convert row to hash using headers
      header_row = spreadsheet.row(1)
      hash_row = {}

      header_row.each_with_index do |header, col_index|
        hash_row[header] = row[col_index]
      end

      data << hash_row
    end

    data
  end

  def read_xml_file(file_path)
    require "nokogiri"

    doc = Nokogiri::XML(File.read(file_path, encoding: "UTF-8"))

    # Convert XML to hash structure
    xml_to_hash(doc.root)
  end

  def xml_to_hash(node)
    return node.text.strip if node.text?

    result = {}

    node.children.each do |child|
      next if child.text?

      key = child.name

      if result[key]
        result[key] = [ result[key] ] unless result[key].is_a?(Array)
        result[key] << xml_to_hash(child)
      else
        result[key] = xml_to_hash(child)
      end
    end

    result
  end

  def process_import_data(data, options = {})
    case data
    when Array
      # Determine record type based on data structure
      record_type = determine_record_type(data.first)

      case record_type
      when :tea_lot
        bulk_import_tea_lots(data, options)
      when :process_event
        bulk_import_process_events(data, options)
      when :shipment
        bulk_import_shipments(data, options)
      else
        raise ValidationError, "Unable to determine record type from data structure"
      end
    when Hash
      # Process structured data with multiple record types
      if data.key?("tea_lots")
        bulk_import_tea_lots(data["tea_lots"], options)
      end

      if data.key?("process_events")
        bulk_import_process_events(data["process_events"], options)
      end

      if data.key?("shipments")
        bulk_import_shipments(data["shipments"], options)
      end
    else
      raise ValidationError, "Invalid data format"
    end
  end

  def determine_record_type(record)
    if record.key?("lot_code") || record.key?(:lot_code)
      :tea_lot
    elsif record.key?("event_type") || record.key?(:event_type)
      :process_event
    elsif record.key?("destination") || record.key?(:destination)
      :shipment
    else
      :unknown
    end
  end

  def import_single_tea_lot(lot_data, options = {})
    lot_code = lot_data[:lot_code] || lot_data["lot_code"]

    tea_lot = TeaLot.find_or_initialize_by(lot_code: lot_code)

    if tea_lot.new_record?
      @stats[:tea_lots][:created] += 1
    else
      @stats[:tea_lots][:updated] += 1
    end

    # Map fields and handle data conversion
    mapped_data = map_tea_lot_fields(lot_data)

    # Validate data
    validation = TeaTraceValidator.comprehensive_tea_lot_validation(mapped_data)
    unless validation[:valid]
      raise ValidationError, validation[:errors].join(", ")
    end

    tea_lot.assign_attributes(mapped_data)
    tea_lot.save!
  end

  def import_single_process_event(event_data, options = {})
    tea_lot_id = event_data[:tea_lot_id] || event_data["tea_lot_id"]
    lot_code = event_data[:lot_code] || event_data["lot_code"]

    # Find tea lot
    tea_lot = if tea_lot_id.present?
                TeaLot.find(tea_lot_id)
    elsif lot_code.present?
                TeaLot.find_by(lot_code: lot_code)
    else
                raise ValidationError, "Tea lot reference is required"
    end

    raise ValidationError, "Tea lot not found" unless tea_lot

    process_event = tea_lot.process_events.build

    @stats[:process_events][:created] += 1

    # Map fields and handle data conversion
    mapped_data = map_process_event_fields(event_data)

    # Validate data
    validation = TeaTraceValidator.validate_business_rules(tea_lot, :create_event, mapped_data)
    unless validation[:valid]
      raise ValidationError, validation[:errors].join(", ")
    end

    process_event.assign_attributes(mapped_data)
    process_event.save!
  end

  def import_single_shipment(shipment_data, options = {})
    tea_lot_id = shipment_data[:tea_lot_id] || shipment_data["tea_lot_id"]
    lot_code = shipment_data[:lot_code] || shipment_data["lot_code"]

    # Find tea lot
    tea_lot = if tea_lot_id.present?
                TeaLot.find(tea_lot_id)
    elsif lot_code.present?
                TeaLot.find_by(lot_code: lot_code)
    else
                raise ValidationError, "Tea lot reference is required"
    end

    raise ValidationError, "Tea lot not found" unless tea_lot

    shipment = tea_lot.shipments.build

    @stats[:shipments][:created] += 1

    # Map fields and handle data conversion
    mapped_data = map_shipment_fields(shipment_data)

    # Validate data
    validation = TeaTraceValidator.validate_business_rules(tea_lot, :create_shipment, mapped_data)
    unless validation[:valid]
      raise ValidationError, validation[:errors].join(", ")
    end

    shipment.assign_attributes(mapped_data)
    shipment.save!
  end

  def map_tea_lot_fields(data)
    {
      lot_code: data[:lot_code] || data["lot_code"],
      origin: data[:origin] || data["origin"],
      variety: data[:variety] || data["variety"],
      harvest_date: parse_date(data[:harvest_date] || data["harvest_date"]),
      quantity_kg: parse_decimal(data[:quantity_kg] || data["quantity_kg"]),
      status: data[:status] || data["status"] || "received"
    }
  end

  def map_process_event_fields(data)
    {
      event_type: data[:event_type] || data["event_type"],
      occurred_at: parse_datetime(data[:occurred_at] || data["occurred_at"]),
      note: data[:note] || data["note"]
    }
  end

  def map_shipment_fields(data)
    {
      destination: data[:destination] || data["destination"],
      shipped_at: parse_date(data[:shipped_at] || data["shipped_at"]),
      quantity_kg: parse_decimal(data[:quantity_kg] || data["quantity_kg"])
    }
  end

  def parse_date(value)
    return nil if value.blank?

    case value
    when Date
      value
    when String
      Date.parse(value)
    when Time, DateTime
      value.to_date
    else
      value.to_s.to_date
    end
  rescue
    nil
  end

  def parse_datetime(value)
    return nil if value.blank?

    case value
    when Time, DateTime
      value
    when String
      DateTime.parse(value)
    when Date
      value.to_time
    else
      value.to_s.to_datetime
    end
  rescue
    nil
  end

  def parse_decimal(value)
    return nil if value.blank?

    case value
    when Numeric
      value
    when String
      value.to_d
    else
      value.to_s.to_d
    end
  rescue
    nil
  end

  def validate_single_record(record, options = {})
    record_type = determine_record_type(record)

    case record_type
    when :tea_lot
      validate_tea_lot_record(record)
    when :process_event
      validate_process_event_record(record)
    when :shipment
      validate_shipment_record(record)
    else
      [ "Unable to determine record type" ]
    end
  end

  def validate_tea_lot_record(record)
    errors = []

    errors << "Lot code is required" unless record[:lot_code] || record["lot_code"]
    errors << "Origin is required" unless record[:origin] || record["origin"]
    errors << "Variety is required" unless record[:variety] || record["variety"]
    errors << "Harvest date is required" unless record[:harvest_date] || record["harvest_date"]
    errors << "Quantity is required" unless record[:quantity_kg] || record["quantity_kg"]

    errors
  end

  def validate_process_event_record(record)
    errors = []

    errors << "Event type is required" unless record[:event_type] || record["event_type"]
    errors << "Tea lot reference is required" unless
      (record[:tea_lot_id] || record["tea_lot_id"]) ||
      (record[:lot_code] || record["lot_code"])

    errors
  end

  def validate_shipment_record(record)
    errors = []

    errors << "Destination is required" unless record[:destination] || record["destination"]
    errors << "Shipped date is required" unless record[:shipped_at] || record["shipped_at"]
    errors << "Quantity is required" unless record[:quantity_kg] || record["quantity_kg"]
    errors << "Tea lot reference is required" unless
      (record[:tea_lot_id] || record["tea_lot_id"]) ||
      (record[:lot_code] || record["lot_code"])

    errors
  end

  def count_nested_records(data)
    count = 0

    if data.is_a?(Hash)
      count += data["tea_lots"]&.count || 0
      count += data["process_events"]&.count || 0
      count += data["shipments"]&.count || 0
    end

    count
  end

  def export_csv_template
    CSV.generate(headers: true) do |csv|
      # Tea Lots template
      csv << [ "Record Type", "Lot Code", "Origin", "Variety", "Harvest Date", "Quantity (kg)", "Status" ]
      csv << [ "tea_lot", "TL-2024-001", "鹿児島", "やぶきた", "2024-05-15", "120.5", "received" ]

      # Process Events template
      csv << [ "Record Type", "Lot Code", "Event Type", "Occurred At", "Note" ]
      csv << [ "process_event", "TL-2024-001", "steaming", "2024-05-16 09:00", "蒸し工程完了" ]

      # Shipments template
      csv << [ "Record Type", "Lot Code", "Destination", "Shipped Date", "Quantity (kg)" ]
      csv << [ "shipment", "TL-2024-001", "東京卸売市場", "2024-05-18", "60.5" ]
    end
  end

  def export_json_template
    {
      tea_lots: [
        {
          lot_code: "TL-2024-001",
          origin: "鹿児島",
          variety: "やぶきた",
          harvest_date: "2024-05-15",
          quantity_kg: 120.5,
          status: "received"
        }
      ],
      process_events: [
        {
          lot_code: "TL-2024-001",
          event_type: "steaming",
          occurred_at: "2024-05-16T09:00:00Z",
          note: "蒸し工程完了"
        }
      ],
      shipments: [
        {
          lot_code: "TL-2024-001",
          destination: "東京卸売市場",
          shipped_at: "2024-05-18",
          quantity_kg: 60.5
        }
      ]
    }.to_json
  end

  def export_excel_template
    # This would use a library like AXLSX or Spreadsheet
    # For now, return CSV format as fallback
    export_csv_template
  end

  def log_start(operation, details)
    @import_log << {
      timestamp: Time.current,
      level: "info",
      operation: operation,
      details: details
    }
  end

  def log_success(operation, details)
    @import_log << {
      timestamp: Time.current,
      level: "success",
      operation: operation,
      details: details
    }
  end

  def log_error(operation, details)
    @errors << "#{operation}: #{details}"
    @import_log << {
      timestamp: Time.current,
      level: "error",
      operation: operation,
      details: details
    }
  end

  def log_completion
    @import_log << {
      timestamp: Time.current,
      level: "info",
      operation: "Import Completed",
      details: generate_import_summary
    }
  end

  def generate_import_summary
    total_created = @stats.values.map { |s| s[:created] }.sum
    total_updated = @stats.values.map { |s| s[:updated] }.sum
    total_failed = @stats.values.map { |s| s[:failed] }.sum

    "Created: #{total_created}, Updated: #{total_updated}, Failed: #{total_failed}"
  end

  def calculate_success_rate
    total_records = @stats.values.map { |s| s[:created] + s[:updated] + s[:failed] }.sum
    successful_records = @stats.values.map { |s| s[:created] + s[:updated] }.sum

    return 0 if total_records == 0

    (successful_records.to_f / total_records * 100).round(1)
  end
end
