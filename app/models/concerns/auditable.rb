module Auditable
  extend ActiveSupport::Concern

  included do
    # Add any class-level configurations here
  end

  class_methods do
    def audit_trail_enabled?
      true
    end

    def audit_fields
      # Define which fields should be tracked for changes
      case self.name
      when 'TeaLot'
        %w[lot_code origin variety harvest_date quantity_kg status]
      when 'ProcessEvent'
        %w[event_type occurred_at note]
      when 'Shipment'
        %w[destination shipped_at quantity_kg]
      else
        []
      end
    end

    def create_audit_log(record, action, changes = {}, user = nil)
      audit_entry = {
        id: SecureRandom.uuid,
        record_type: self.name,
        record_id: record.id,
        action: action,
        changes: changes,
        user_id: user&.id,
        user_email: user&.email,
        timestamp: Time.current,
        ip_address: current_request_ip,
        user_agent: current_user_agent
      }
      
      # Store audit log (in a real implementation, this would save to a database table)
      store_audit_entry(audit_entry)
      
      audit_entry
    end

    def get_audit_history(record_id, options = {})
      # Retrieve audit history for a specific record
      audit_logs = retrieve_audit_logs(self.name, record_id)
      
      if options[:limit]
        audit_logs = audit_logs.limit(options[:limit])
      end
      
      if options[:order]
        audit_logs = audit_logs.order(options[:order] == :asc ? :timestamp : { timestamp: :desc })
      else
        audit_logs = audit_logs.order(timestamp: :desc)
      end
      
      audit_logs
    end

    def get_audit_summary(options = {})
      # Get summary of audit activity
      {
        total_audits: count_audit_logs,
        audits_by_type: count_audits_by_type,
        audits_by_action: count_audits_by_action,
        recent_activity: get_recent_audit_activity(options[:limit] || 10)
      }
    end

    def search_audit_logs(query, options = {})
      # Search audit logs
      search_conditions = build_audit_search_conditions(query)
      
      retrieve_audit_logs(nil, search_conditions, options)
    end

    def export_audit_logs(format = :csv, options = {})
      # Export audit logs in various formats
      logs = retrieve_audit_logs(nil, nil, options)
      
      case format.to_sym
      when :csv
        export_audit_logs_to_csv(logs)
      when :json
        logs.to_json
      when :xml
        export_audit_logs_to_xml(logs)
      else
        logs.to_json
      end
    end

    def audit_compliance_report(options = {})
      # Generate compliance report based on audit logs
      {
        compliance_score: calculate_compliance_score,
        compliance_issues: identify_compliance_issues,
        audit_coverage: calculate_audit_coverage,
        recommendations: generate_compliance_recommendations
      }
    end

    private

    def store_audit_entry(audit_entry)
      # In a real implementation, this would save to an audit_logs table
      # For now, store in memory or file-based storage
      Rails.cache.write("audit_#{audit_entry[:id]}", audit_entry, expires_in: 1.year)
      
      # Also add to a list for this record type
      type_key = "audit_list_#{self.name}"
      current_list = Rails.cache.read(type_key) || []
      current_list << audit_entry[:id]
      Rails.cache.write(type_key, current_list, expires_in: 1.year)
    end

    def retrieve_audit_logs(record_type = nil, record_id = nil, conditions = nil, options = {})
      # In a real implementation, this would query the audit_logs table
      # For now, retrieve from cache
      all_audit_ids = Rails.cache.read("audit_list_#{record_type || self.name}") || []
      
      audit_logs = all_audit_ids.map do |audit_id|
        Rails.cache.read("audit_#{audit_id}")
      end.compact
      
      # Filter by record ID if specified
      if record_id
        audit_logs = audit_logs.select { |log| log[:record_id] == record_id }
      end
      
      # Apply additional conditions
      if conditions
        audit_logs = apply_audit_conditions(audit_logs, conditions)
      end
      
      # Apply options
      if options[:limit]
        audit_logs = audit_logs.first(options[:limit])
      end
      
      if options[:order]
        direction = options[:order] == :asc ? :asc : :desc
        audit_logs = audit_logs.sort_by { |log| log[:timestamp] }
        audit_logs.reverse! if direction == :desc
      else
        audit_logs = audit_logs.sort_by { |log| log[:timestamp] }.reverse
      end
      
      audit_logs
    end

    def apply_audit_conditions(logs, conditions)
      logs.select do |log|
        match = true
        
        conditions.each do |key, value|
          case key
          when :action
            match &&= log[:action] == value.to_s
          when :user_id
            match &&= log[:user_id] == value
          when :date_range
            if value.is_a?(Range)
              match &&= value.include?(log[:timestamp].to_date)
            end
          when :search
            match &&= log.to_s.downcase.include?(value.to_s.downcase)
          end
        end
        
        match
      end
    end

    def build_audit_search_conditions(query)
      # Build search conditions for audit logs
      {
        search: query
      }
    end

    def count_audit_logs
      all_audit_ids = Rails.cache.read("audit_list_#{self.name}") || []
      all_audit_ids.count
    end

    def count_audits_by_type
      # Count audits by record type
      type_counts = {}
      
      %w[TeaLot ProcessEvent Shipment].each do |type|
        audit_ids = Rails.cache.read("audit_list_#{type}") || []
        type_counts[type] = audit_ids.count
      end
      
      type_counts
    end

    def count_audits_by_action
      # Count audits by action type
      action_counts = { 'create' => 0, 'update' => 0, 'delete' => 0 }
      
      all_audit_ids = Rails.cache.read("audit_list_#{self.name}") || []
      
      all_audit_ids.each do |audit_id|
        audit = Rails.cache.read("audit_#{audit_id}")
        if audit && action_counts.key?(audit[:action])
          action_counts[audit[:action]] += 1
        end
      end
      
      action_counts
    end

    def get_recent_audit_activity(limit = 10)
      # Get recent audit activity
      all_audit_ids = Rails.cache.read("audit_list_#{self.name}") || []
      
      recent_audits = all_audit_ids.map do |audit_id|
        Rails.cache.read("audit_#{audit_id}")
      end.compact
      
      recent_audits.sort_by { |audit| audit[:timestamp] }.reverse.first(limit)
    end

    def calculate_compliance_score
      # Calculate compliance score based on audit coverage and completeness
      total_records = count
      audited_records = count_distinct_audited_records
      
      return 100 if total_records == 0
      
      coverage_score = (audited_records.to_f / total_records * 100).round(1)
      
      # Add other compliance factors
      completeness_score = calculate_audit_completeness
      timeliness_score = calculate_audit_timeliness
      
      ((coverage_score + completeness_score + timeliness_score) / 3).round(1)
    end

    def calculate_audit_coverage
      total_records = count
      audited_records = count_distinct_audited_records
      
      return 100 if total_records == 0
      
      (audited_records.to_f / total_records * 100).round(1)
    end

    def calculate_audit_completeness
      # Check if all required fields are being audited
      required_fields = audit_fields
      total_fields = required_fields.length
      
      # In a real implementation, this would check actual audit data
      # For now, assume 90% completeness
      90.0
    end

    def calculate_audit_timeliness
      # Check if audits are being created in a timely manner
      # In a real implementation, this would analyze audit timestamps
      # For now, assume 95% timeliness
      95.0
    end

    def count_distinct_audited_records
      # Count distinct records that have audit logs
      all_audit_ids = Rails.cache.read("audit_list_#{self.name}") || []
      
      distinct_record_ids = all_audit_ids.map do |audit_id|
        audit = Rails.cache.read("audit_#{audit_id}")
        audit[:record_id] if audit
      end.compact.uniq
      
      distinct_record_ids.count
    end

    def identify_compliance_issues
      # Identify compliance issues based on audit logs
      issues = []
      
      # Check for records without audit logs
      unaudited_records = count - count_distinct_audited_records
      if unaudited_records > 0
        issues << "#{unaudited_records} records without audit logs"
      end
      
      # Check for unusual patterns
      recent_activity = get_recent_audit_activity(100)
      suspicious_patterns = identify_suspicious_patterns(recent_activity)
      issues.concat(suspicious_patterns)
      
      issues
    end

    def identify_suspicious_patterns(audit_logs)
      # Identify suspicious patterns in audit logs
      patterns = []
      
      # Check for bulk operations
      bulk_operations = identify_bulk_operations(audit_logs)
      patterns.concat(bulk_operations)
      
      # Check for unusual timing
      unusual_timing = identify_unusual_timing(audit_logs)
      patterns.concat(unusual_timing)
      
      patterns
    end

    def identify_bulk_operations(audit_logs)
      # Identify bulk operations (many similar actions in short time)
      patterns = []
      
      # Group by action and timestamp
      grouped_actions = audit_logs.group_by { |log| [log[:action], log[:timestamp].to_date] }
      
      grouped_actions.each do |(action, date), logs|
        if logs.count > 50 # More than 50 similar actions in one day
          patterns << "Bulk #{action} operation detected on #{date}: #{logs.count} records"
        end
      end
      
      patterns
    end

    def identify_unusual_timing(audit_logs)
      # Identify unusual timing patterns
      patterns = []
      
      # Check for operations outside business hours
      off_hours_operations = audit_logs.select do |log|
        hour = log[:timestamp].hour
        hour < 6 || hour > 22
      end
      
      if off_hours_operations.count > audit_logs.count * 0.1
        patterns << "High number of operations outside business hours: #{off_hours_operations.count}"
      end
      
      patterns
    end

    def generate_compliance_recommendations
      # Generate compliance recommendations
      recommendations = []
      
      coverage = calculate_audit_coverage
      if coverage < 95
        recommendations << "Increase audit coverage to at least 95%"
      end
      
      completeness = calculate_audit_completeness
      if completeness < 95
        recommendations << "Improve audit completeness by tracking all required fields"
      end
      
      timeliness = calculate_audit_timeliness
      if timeliness < 95
        recommendations << "Ensure audit logs are created in a timely manner"
      end
      
      recommendations
    end

    def export_audit_logs_to_csv(logs)
      CSV.generate(headers: true) do |csv|
        csv << [
          'ID', 'Record Type', 'Record ID', 'Action', 'User ID', 'User Email',
          'Timestamp', 'IP Address', 'Changes'
        ]
        
        logs.each do |log|
          csv << [
            log[:id],
            log[:record_type],
            log[:record_id],
            log[:action],
            log[:user_id],
            log[:user_email],
            log[:timestamp],
            log[:ip_address],
            log[:changes].to_json
          ]
        end
      end
    end

    def export_audit_logs_to_xml(logs)
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.audit_logs do
          logs.each do |log|
            xml.audit_log do
              xml.id log[:id]
              xml.record_type log[:record_type]
              xml.record_id log[:record_id]
              xml.action log[:action]
              xml.user_id log[:user_id]
              xml.user_email log[:user_email]
              xml.timestamp log[:timestamp]
              xml.ip_address log[:ip_address]
              xml.changes log[:changes].to_json
            end
          end
        end
      end
      
      builder.to_xml
    end

    def current_request_ip
      # In a real implementation, this would get the current request IP
      '127.0.0.1'
    end

    def current_user_agent
      # In a real implementation, this would get the current user agent
      'TeaTrace System'
    end
  end

  def create_audit(action, changes = {}, user = nil)
    return unless self.class.audit_trail_enabled?
    
    # Filter changes to only include audited fields
    filtered_changes = filter_audit_changes(changes)
    
    self.class.create_audit_log(self, action, filtered_changes, user)
  end

  def audit_history(options = {})
    self.class.get_audit_history(id, options)
  end

  def audit_summary
    {
      total_audits: audit_history.count,
      last_audited: audit_history.first&.dig(:timestamp),
      audit_trail_complete: audit_trail_complete?
    }
  end

  def audit_trail_complete?
    # Check if the audit trail is complete for this record
    required_actions = %w[create]
    
    audit_actions = audit_history.pluck(:action)
    required_actions.all? { |action| audit_actions.include?(action) }
  end

  def recent_audit_activity(days = 30)
    cutoff_date = days.days.ago
    
    audit_history.select do |audit|
      audit[:timestamp] > cutoff_date
    end
  end

  def audit_compliance_score
    # Calculate individual record compliance score
    base_score = 50
    
    # Add points for having create audit
    create_audit = audit_history.find { |a| a[:action] == 'create' }
    base_score += 30 if create_audit
    
    # Add points for having update audits
    update_audits = audit_history.select { |a| a[:action] == 'update' }
    base_score += [update_audits.count * 5, 20].min
    
    # Add points for completeness
    base_score += audit_trail_complete? ? 0 : -10
    
    [base_score, 0].max
  end

  def export_audit_trail(format = :json)
    audit_data = {
      record: self.as_json,
      audit_history: audit_history,
      audit_summary: audit_summary,
      compliance_score: audit_compliance_score
    }
    
    case format.to_sym
    when :json
      audit_data.to_json
    when :csv
      export_audit_trail_to_csv(audit_data)
    when :xml
      export_audit_trail_to_xml(audit_data)
    else
      audit_data.to_json
    end
  end

  private

  def filter_audit_changes(changes)
    # Filter changes to only include audited fields
    audited_fields = self.class.audit_fields
    
    filtered_changes = {}
    
    changes.each do |field, change|
      if audited_fields.include?(field.to_s)
        filtered_changes[field] = change
      end
    end
    
    filtered_changes
  end

  def export_audit_trail_to_csv(audit_data)
    CSV.generate(headers: true) do |csv|
      # Record information
      csv << ['Section', 'Field', 'Value']
      
      audit_data[:record].each do |key, value|
        csv << ['Record', key, value]
      end
      
      # Audit summary
      csv << ['Summary', 'Total Audits', audit_data[:audit_summary][:total_audits]]
      csv << ['Summary', 'Last Audited', audit_data[:audit_summary][:last_audited]]
      csv << ['Summary', 'Compliance Score', audit_data[:audit_compliance_score]]
      
      # Audit history
      audit_data[:audit_history].each_with_index do |audit, index|
        csv << ["Audit #{index + 1}", 'Action', audit[:action]]
        csv << ["Audit #{index + 1}", 'Timestamp', audit[:timestamp]]
        csv << ["Audit #{index + 1}", 'User', audit[:user_email]]
        csv << ["Audit #{index + 1}", 'Changes', audit[:changes].to_json]
      end
    end
  end

  def export_audit_trail_to_xml(audit_data)
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.audit_trail do
        xml.record do
          audit_data[:record].each do |key, value|
            xml.send(key, value)
          end
        end
        
        xml.audit_summary do
          xml.total_audits audit_data[:audit_summary][:total_audits]
          xml.last_audited audit_data[:audit_summary][:last_audited]
          xml.compliance_score audit_data[:audit_compliance_score]
        end
        
        xml.audit_history do
          audit_data[:audit_history].each_with_index do |audit, index|
            xml.audit(index: index) do
              xml.action audit[:action]
              xml.timestamp audit[:timestamp]
              xml.user_email audit[:user_email]
              xml.changes audit[:changes].to_json
            end
          end
        end
      end
    end
    
    builder.to_xml
  end
end
