module Traceable
  extend ActiveSupport::Concern

  included do
    # Add any class-level configurations here
  end

  class_methods do
    def traceable_by_lot_code(lot_code)
      where(lot_code: lot_code)
    end

    def traceable_by_origin(origin)
      where("origin ILIKE ?", "%#{origin}%")
    end

    def traceable_by_date_range(start_date, end_date)
      if respond_to?(:harvest_date)
        where(harvest_date: start_date..end_date)
      elsif respond_to?(:occurred_at)
        where(occurred_at: start_date..end_date)
      elsif respond_to?(:shipped_at)
        where(shipped_at: start_date..end_date)
      end
    end

    def traceable_by_status(status)
      where(status: status) if respond_to?(:status)
    end

    def traceability_summary
      {
        total_records: count,
        created_at_range: {
          earliest: minimum(:created_at),
          latest: maximum(:created_at)
        },
        updated_at_range: {
          earliest: minimum(:updated_at),
          latest: maximum(:updated_at)
        }
      }
    end
  end

  def traceability_info
    {
      id: id,
      created_at: created_at,
      updated_at: updated_at,
      record_age_days: ((Time.current - created_at) / 1.day).round(1),
      last_updated_days: ((Time.current - updated_at) / 1.day).round(1)
    }
  end

  def traceability_history
    # This would typically integrate with a paper trail or audit log system
    # For now, return basic information
    {
      current_state: as_json,
      last_modified: updated_at,
      modification_count: 1 # This would come from audit logs in a real implementation
    }
  end

  def traceability_chain
    # Build the complete traceability chain for this record
    chain = [traceability_info]
    
    # Add related records based on the model type
    case self.class.name
    when 'TeaLot'
      chain.concat(traceability_chain_for_tea_lot)
    when 'ProcessEvent'
      chain.concat(traceability_chain_for_process_event)
    when 'Shipment'
      chain.concat(traceability_chain_for_shipment)
    end
    
    chain
  end

  def traceability_score
    # Calculate a traceability score based on data completeness
    base_score = 50
    
    # Add points for complete data
    score_factors = calculate_traceability_factors
    
    total_score = base_score + score_factors.values.sum
    [total_score, 100].min
  end

  def traceability_grade
    score = traceability_score
    
    case score
    when 90..100
      'A+ (Excellent)'
    when 80..89
      'A (Very Good)'
    when 70..79
      'B (Good)'
    when 60..69
      'C (Fair)'
    when 50..59
      'D (Poor)'
    else
      'F (Very Poor)'
    end
  end

  def traceability_completeness
    # Calculate what percentage of required fields are filled
    required_fields = get_required_fields
    filled_fields = required_fields.count { |field| send(field).present? }
    
    (filled_fields.to_f / required_fields.count * 100).round(1)
  end

  def traceability_validation
    # Validate traceability requirements
    errors = []
    warnings = []
    
    # Check for missing critical data
    missing_critical_fields = get_critical_fields.select { |field| send(field).blank? }
    if missing_critical_fields.any?
      errors << "Critical traceability fields missing: #{missing_critical_fields.join(', ')}"
    end
    
    # Check for data consistency
    warnings.concat(check_data_consistency)
    
    # Check for timeliness
    warnings.concat(check_data_timeliness)
    
    {
      valid: errors.empty?,
      errors: errors,
      warnings: warnings,
      completeness: traceability_completeness
    }
  end

  def traceability_export(format = :json)
    case format.to_sym
    when :json
      export_traceability_to_json
    when :csv
      export_traceability_to_csv
    when :xml
      export_traceability_to_xml
    else
      export_traceability_to_json
    end
  end

  def traceability_audit_trail
    # In a real implementation, this would query an audit log table
    # For now, return a mock audit trail
    [
      {
        action: 'created',
        timestamp: created_at,
        user: 'system',
        changes: 'Initial record creation'
      },
      {
        action: 'updated',
        timestamp: updated_at,
        user: 'system',
        changes: 'Last modification'
      }
    ]
  end

  private

  def traceability_chain_for_tea_lot
    chain = []
    
    # Add process events
    process_events.order(:occurred_at).each do |event|
      chain << {
        type: 'process_event',
        data: event.traceability_info,
        relationship: 'processing_step'
      }
    end
    
    # Add shipments
    shipments.order(:shipped_at).each do |shipment|
      chain << {
        type: 'shipment',
        data: shipment.traceability_info,
        relationship: 'distribution'
      }
    end
    
    chain
  end

  def traceability_chain_for_process_event
    chain = []
    
    # Add tea lot info
    chain << {
      type: 'tea_lot',
      data: tea_lot.traceability_info,
      relationship: 'belongs_to'
    }
    
    # Add related events
    tea_lot.process_events.where.not(id: id).order(:occurred_at).each do |event|
      chain << {
        type: 'related_process_event',
        data: event.traceability_info,
        relationship: 'sibling_event'
      }
    end
    
    chain
  end

  def traceability_chain_for_shipment
    chain = []
    
    # Add tea lot info
    chain << {
      type: 'tea_lot',
      data: tea_lot.traceability_info,
      relationship: 'origin'
    }
    
    # Add related shipments
    tea_lot.shipments.where.not(id: id).order(:shipped_at).each do |shipment|
      chain << {
        type: 'related_shipment',
        data: shipment.traceability_info,
        relationship: 'sibling_shipment'
      }
    end
    
    chain
  end

  def calculate_traceability_factors
    factors = {}
    
    # Data completeness factors
    factors[:data_completeness] = (traceability_completeness / 100.0) * 30
    
    # Timeliness factors
    factors[:timeliness] = calculate_timeliness_score
    
    # Consistency factors
    factors[:consistency] = calculate_consistency_score
    
    # Relationship factors
    factors[:relationships] = calculate_relationship_score
    
    factors
  end

  def calculate_timeliness_score
    # Score based on how recent the data is
    days_since_update = (Time.current - updated_at) / 1.day
    
    case days_since_update
    when 0..7
      20
    when 8..30
      15
    when 31..90
      10
    when 91..365
      5
    else
      0
    end
  end

  def calculate_consistency_score
    # Score based on internal data consistency
    score = 10
    
    # Check for logical consistency
    case self.class.name
    when 'TeaLot'
      score -= 2 if harvest_date.present? && harvest_date > Date.current
      score -= 2 if quantity_kg.present? && quantity_kg <= 0
    when 'ProcessEvent'
      score -= 2 if occurred_at.present? && tea_lot.present? && occurred_at.to_date < tea_lot.harvest_date
    when 'Shipment'
      score -= 2 if shipped_at.present? && tea_lot.present? && shipped_at < tea_lot.harvest_date
      score -= 2 if quantity_kg.present? && quantity_kg <= 0
    end
    
    [score, 0].max
  end

  def calculate_relationship_score
    # Score based on relationship integrity
    score = 10
    
    case self.class.name
    when 'TeaLot'
      score -= 3 if process_events.empty?
      score -= 2 if shipments.empty?
    when 'ProcessEvent'
      score -= 5 unless tea_lot.present?
    when 'Shipment'
      score -= 5 unless tea_lot.present?
    end
    
    [score, 0].max
  end

  def get_required_fields
    case self.class.name
    when 'TeaLot'
      %w[lot_code origin variety harvest_date quantity_kg status]
    when 'ProcessEvent'
      %w[event_type occurred_at]
    when 'Shipment'
      %w[destination shipped_at quantity_kg]
    else
      []
    end
  end

  def get_critical_fields
    case self.class.name
    when 'TeaLot'
      %w[lot_code harvest_date quantity_kg]
    when 'ProcessEvent'
      %w[event_type occurred_at tea_lot_id]
    when 'Shipment'
      %w[destination shipped_at quantity_kg tea_lot_id]
    else
      []
    end
  end

  def check_data_consistency
    warnings = []
    
    case self.class.name
    when 'TeaLot'
      if harvest_date.present? && harvest_date > Date.current
        warnings << "Harvest date is in the future"
      end
      if quantity_kg.present? && quantity_kg > 10000
        warnings << "Unusually large quantity (>10,000 kg)"
      end
    when 'ProcessEvent'
      if occurred_at.present? && tea_lot.present? && occurred_at.to_date < tea_lot.harvest_date
        warnings << "Process event occurred before harvest date"
      end
    when 'Shipment'
      if shipped_at.present? && tea_lot.present? && shipped_at < tea_lot.harvest_date
        warnings << "Shipment date is before harvest date"
      end
    end
    
    warnings
  end

  def check_data_timeliness
    warnings = []
    
    days_since_update = (Time.current - updated_at) / 1.day
    
    if days_since_update > 365
      warnings << "Record has not been updated in over a year"
    elsif days_since_update > 90
      warnings << "Record has not been updated in over 90 days"
    end
    
    warnings
  end

  def export_traceability_to_json
    {
      record_type: self.class.name,
      traceability_info: traceability_info,
      traceability_score: traceability_score,
      traceability_grade: traceability_grade,
      completeness: traceability_completeness,
      validation: traceability_validation,
      chain: traceability_chain
    }.to_json
  end

  def export_traceability_to_csv
    # Simplified CSV export for traceability data
    CSV.generate do |csv|
      csv << ['Field', 'Value']
      
      traceability_info.each do |key, value|
        csv << [key, value]
      end
      
      csv << ['Traceability Score', traceability_score]
      csv << ['Traceability Grade', traceability_grade]
      csv << ['Completeness', "#{traceability_completeness}%"]
    end
  end

  def export_traceability_to_xml
    # Simplified XML export
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.traceability_record do
        xml.record_type self.class.name
        xml.traceability_score traceability_score
        xml.traceability_grade traceability_grade
        xml.completeness traceability_completeness
        
        traceability_info.each do |key, value|
          xml.send(key, value)
        end
      end
    end
    
    builder.to_xml
  end
end
