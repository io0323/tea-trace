module Reportable
  extend ActiveSupport::Concern

  included do
    # Add any class-level configurations here
  end

  class_methods do
    def generate_report(report_type, options = {})
      case report_type.to_sym
      when :summary
        generate_summary_report(options)
      when :detailed
        generate_detailed_report(options)
      when :analytics
        generate_analytics_report(options)
      when :traceability
        generate_traceability_report(options)
      when :performance
        generate_performance_report(options)
      else
        raise ArgumentError, "Unknown report type: #{report_type}"
      end
    end

    def export_to_format(data, format = :csv)
      case format.to_sym
      when :csv
        export_to_csv(data)
      when :json
        export_to_json(data)
      when :xml
        export_to_xml(data)
      when :pdf
        export_to_pdf(data)
      else
        raise ArgumentError, "Unsupported export format: #{format}"
      end
    end

    def report_templates
      [
        {
          name: 'summary_report',
          description: 'Basic summary of all records',
          fields: %w[id created_at updated_at],
          filters: %w[date_range status]
        },
        {
          name: 'detailed_report',
          description: 'Comprehensive report with all fields',
          fields: 'all',
          filters: %w[date_range status origin variety]
        },
        {
          name: 'analytics_report',
          description: 'Statistical analysis and metrics',
          fields: %w[count average sum min max],
          filters: %w[date_range group_by]
        }
      ]
    end

    def scheduled_reports
      [
        {
          name: 'daily_summary',
          frequency: 'daily',
          report_type: :summary,
          recipients: %w[manager@company.com],
          enabled: true
        },
        {
          name: 'weekly_analytics',
          frequency: 'weekly',
          report_type: :analytics,
          recipients: %w[analyst@company.com manager@company.com],
          enabled: true
        },
        {
          name: 'monthly_traceability',
          frequency: 'monthly',
          report_type: :traceability,
          recipients: %w[quality@company.com],
          enabled: false
        }
      ]
    end

    private

    def generate_summary_report(options)
      scope = apply_filters(options)
      
      {
        title: "#{self.name} Summary Report",
        generated_at: Time.current,
        filters: options,
        summary: {
          total_records: scope.count,
          date_range: {
            start: options[:start_date],
            end: options[:end_date]
          }
        },
        data: scope.limit(options[:limit] || 1000)
                   .as_json(only: %w[id created_at updated_at])
      }
    end

    def generate_detailed_report(options)
      scope = apply_filters(options)
      
      {
        title: "#{self.name} Detailed Report",
        generated_at: Time.current,
        filters: options,
        summary: {
          total_records: scope.count,
          date_range: {
            start: options[:start_date],
            end: options[:end_date]
          }
        },
        data: scope.limit(options[:limit] || 1000).as_json
      }
    end

    def generate_analytics_report(options)
      scope = apply_filters(options)
      
      {
        title: "#{self.name} Analytics Report",
        generated_at: Time.current,
        filters: options,
        analytics: calculate_analytics(scope),
        trends: calculate_trends(scope, options),
        distributions: calculate_distributions(scope)
      }
    end

    def generate_traceability_report(options)
      scope = apply_filters(options)
      
      {
        title: "#{self.name} Traceability Report",
        generated_at: Time.current,
        filters: options,
        traceability_metrics: calculate_traceability_metrics(scope),
        compliance_status: check_compliance(scope),
        audit_trail: generate_audit_summary(scope)
      }
    end

    def generate_performance_report(options)
      scope = apply_filters(options)
      
      {
        title: "#{self.name} Performance Report",
        generated_at: Time.current,
        filters: options,
        performance_metrics: calculate_performance_metrics(scope),
        benchmarks: calculate_benchmarks(scope),
        recommendations: generate_recommendations(scope)
      }
    end

    def apply_filters(options)
      scope = all
      
      if options[:start_date].present? && options[:end_date].present?
        if respond_to?(:harvest_date)
          scope = scope.where(harvest_date: options[:start_date]..options[:end_date])
        elsif respond_to?(:occurred_at)
          scope = scope.where(occurred_at: options[:start_date]..options[:end_date])
        elsif respond_to?(:shipped_at)
          scope = scope.where(shipped_at: options[:start_date]..options[:end_date])
        end
      end
      
      if options[:status].present? && respond_to?(:status)
        scope = scope.where(status: options[:status])
      end
      
      if options[:origin].present? && respond_to?(:origin)
        scope = scope.where("origin ILIKE ?", "%#{options[:origin]}%")
      end
      
      if options[:variety].present? && respond_to?(:variety)
        scope = scope.where(variety: options[:variety])
      end
      
      scope
    end

    def calculate_analytics(scope)
      analytics = {}
      
      # Basic statistics
      analytics[:basic_stats] = {
        count: scope.count,
        average: calculate_average(scope),
        sum: calculate_sum(scope),
        min: calculate_min(scope),
        max: calculate_max(scope)
      }
      
      # Time-based analytics
      analytics[:time_stats] = calculate_time_statistics(scope)
      
      # Group-based analytics
      analytics[:group_stats] = calculate_group_statistics(scope)
      
      analytics
    end

    def calculate_trends(scope, options)
      trends = {}
      
      # Daily trends
      if options[:include_daily_trends]
        trends[:daily] = calculate_daily_trends(scope)
      end
      
      # Weekly trends
      if options[:include_weekly_trends]
        trends[:weekly] = calculate_weekly_trends(scope)
      end
      
      # Monthly trends
      if options[:include_monthly_trends]
        trends[:monthly] = calculate_monthly_trends(scope)
      end
      
      trends
    end

    def calculate_distributions(scope)
      distributions = {}
      
      case self.name
      when 'TeaLot'
        distributions[:by_origin] = scope.group(:origin).count
        distributions[:by_variety] = scope.group(:variety).count
        distributions[:by_status] = scope.group(:status).count
        distributions[:quantity_ranges] = calculate_quantity_distribution(scope)
      when 'ProcessEvent'
        distributions[:by_event_type] = scope.group(:event_type).count
        distributions[:by_hour] = scope.group_by_hour(:occurred_at).count
        distributions[:by_day_of_week] = scope.group_by_day_of_week(:occurred_at).count
      when 'Shipment'
        distributions[:by_destination] = scope.group(:destination).count
        distributions[:by_month] = scope.group_by_month(:shipped_at).count
        distributions[:quantity_ranges] = calculate_shipment_quantity_distribution(scope)
      end
      
      distributions
    end

    def calculate_traceability_metrics(scope)
      metrics = {}
      
      if self.name == 'TeaLot'
        metrics[:completeness_scores] = scope.map { |lot| lot.traceability_score }
        metrics[:average_completeness] = metrics[:completeness_scores].sum.to_f / metrics[:completeness_scores].count
        metrics[:grade_distribution] = scope.group_by { |lot| lot.traceability_grade }.transform_values(&:count)
      end
      
      metrics
    end

    def check_compliance(scope)
      compliance = {
        total_records: scope.count,
        compliant_records: 0,
        non_compliant_records: 0,
        compliance_issues: []
      }
      
      scope.each do |record|
        validation = record.traceability_validation
        
        if validation[:valid]
          compliance[:compliant_records] += 1
        else
          compliance[:non_compliant_records] += 1
          compliance[:compliance_issues].concat(validation[:errors])
        end
      end
      
      compliance[:compliance_rate] = (compliance[:compliant_records].to_f / compliance[:total_records] * 100).round(1)
      compliance[:compliance_issues].uniq!
      
      compliance
    end

    def generate_audit_summary(scope)
      {
        total_records: scope.count,
        records_with_changes: scope.where.not(updated_at: :created_at).count,
        average_age_days: scope.average("(CURRENT_DATE - DATE(created_at))").to_f.round(1),
        last_updated_range: {
          earliest: scope.minimum(:updated_at),
          latest: scope.maximum(:updated_at)
        }
      }
    end

    def calculate_performance_metrics(scope)
      metrics = {}
      
      case self.name
      when 'TeaLot'
        metrics[:processing_efficiency] = calculate_processing_efficiency(scope)
        metrics[:shipment_efficiency] = calculate_shipment_efficiency(scope)
      when 'ProcessEvent'
        metrics[:event_frequency] = calculate_event_frequency(scope)
        metrics[:processing_times] = calculate_processing_times(scope)
      when 'Shipment'
        metrics[:shipment_patterns] = calculate_shipment_patterns(scope)
      end
      
      metrics
    end

    def calculate_benchmarks(scope)
      benchmarks = {}
      
      # Industry benchmarks (mock data for demonstration)
      industry_benchmarks = {
        'TeaLot' => {
          average_processing_time: 72, # hours
          average_shipment_time: 30, # days
          traceability_score: 85
        },
        'ProcessEvent' => {
          events_per_day: 10,
          average_event_duration: 2 # hours
        },
        'Shipment' => {
          average_shipment_size: 50, # kg
          shipment_frequency: 5 # per week
        }
      }
      
      current_metrics = calculate_current_metrics(scope)
      industry_metrics = industry_benchmarks[self.name] || {}
      
      industry_metrics.each do |metric, industry_value|
        current_value = current_metrics[metric]
        if current_value
          benchmarks[metric] = {
            current: current_value,
            industry: industry_value,
            performance: ((current_value.to_f / industry_value - 1) * 100).round(1)
          }
        end
      end
      
      benchmarks
    end

    def generate_recommendations(scope)
      recommendations = []
      
      # Analyze data and generate recommendations
      case self.name
      when 'TeaLot'
        recommendations.concat(generate_tea_lot_recommendations(scope))
      when 'ProcessEvent'
        recommendations.concat(generate_process_event_recommendations(scope))
      when 'Shipment'
        recommendations.concat(generate_shipment_recommendations(scope))
      end
      
      recommendations
    end

    def export_to_csv(data)
      CSV.generate(headers: true) do |csv|
        if data.is_a?(Hash)
          # Export structured data
          csv << ['Section', 'Key', 'Value']
          
          data.each do |section, content|
            if content.is_a?(Hash)
              content.each do |key, value|
                csv << [section, key, value]
              end
            else
              csv << [section, 'data', content]
            end
          end
        elsif data.respond_to?(:each)
          # Export array of records
          if data.any? && data.first.is_a?(Hash)
            csv << data.first.keys
            data.each { |record| csv << record.values }
          else
            csv << ['ID', 'Created At', 'Updated At']
            data.each { |record| csv << [record.id, record.created_at, record.updated_at] }
          end
        end
      end
    end

    def export_to_json(data)
      data.to_json
    end

    def export_to_xml(data)
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.report do
          xml.generated_at Time.current
          xml.data do
            if data.is_a?(Hash)
              data.each do |key, value|
                xml.send(key, value)
              end
            elsif data.respond_to?(:each)
              data.each_with_index do |item, index|
                xml.item(index: index) do
                  if item.is_a?(Hash)
                    item.each do |k, v|
                      xml.send(k, v)
                    end
                  else
                    xml.content item.to_s
                  end
                end
              end
            end
          end
        end
      end
      
      builder.to_xml
    end

    def export_to_pdf(data)
      # This would typically use a PDF generation library like Prawn or Wicked PDF
      # For now, return a placeholder
      "PDF export not implemented. Data: #{data.inspect}"
    end

    # Helper methods for specific calculations
    def calculate_average(scope)
      if respond_to?(:quantity_kg)
        scope.average(:quantity_kg)&.round(2)
      else
        0
      end
    end

    def calculate_sum(scope)
      if respond_to?(:quantity_kg)
        scope.sum(:quantity_kg)
      else
        0
      end
    end

    def calculate_min(scope)
      if respond_to?(:quantity_kg)
        scope.minimum(:quantity_kg)
      else
        0
      end
    end

    def calculate_max(scope)
      if respond_to?(:quantity_kg)
        scope.maximum(:quantity_kg)
      else
        0
      end
    end

    def calculate_time_statistics(scope)
      stats = {}
      
      if respond_to?(:created_at)
        stats[:creation_range] = {
          earliest: scope.minimum(:created_at),
          latest: scope.maximum(:created_at)
        }
      end
      
      if respond_to?(:occurred_at)
        stats[:occurrence_range] = {
          earliest: scope.minimum(:occurred_at),
          latest: scope.maximum(:occurred_at)
        }
      end
      
      if respond_to?(:shipped_at)
        stats[:shipment_range] = {
          earliest: scope.minimum(:shipped_at),
          latest: scope.maximum(:shipped_at)
        }
      end
      
      stats
    end

    def calculate_group_statistics(scope)
      stats = {}
      
      if respond_to?(:status)
        stats[:by_status] = scope.group(:status).count
      end
      
      if respond_to?(:origin)
        stats[:by_origin] = scope.group(:origin).count
      end
      
      if respond_to?(:variety)
        stats[:by_variety] = scope.group(:variety).count
      end
      
      stats
    end

    def calculate_daily_trends(scope)
      if respond_to?(:occurred_at)
        scope.group_by_day(:occurred_at).count
      elsif respond_to?(:shipped_at)
        scope.group_by_day(:shipped_at).count
      else
        scope.group_by_day(:created_at).count
      end
    end

    def calculate_weekly_trends(scope)
      if respond_to?(:occurred_at)
        scope.group_by_week(:occurred_at).count
      elsif respond_to?(:shipped_at)
        scope.group_by_week(:shipped_at).count
      else
        scope.group_by_week(:created_at).count
      end
    end

    def calculate_monthly_trends(scope)
      if respond_to?(:occurred_at)
        scope.group_by_month(:occurred_at).count
      elsif respond_to?(:shipped_at)
        scope.group_by_month(:shipped_at).count
      else
        scope.group_by_month(:created_at).count
      end
    end

    def calculate_quantity_distribution(scope)
      return {} unless respond_to?(:quantity_kg)
      
      ranges = {
        '0-50kg' => 0..50,
        '51-100kg' => 51..100,
        '101-500kg' => 101..500,
        '501-1000kg' => 501..1000,
        '1000kg+' => 1000..Float::INFINITY
      }
      
      distribution = {}
      ranges.each do |label, range|
        distribution[label] = scope.where(quantity_kg: range).count
      end
      
      distribution
    end

    def calculate_shipment_quantity_distribution(scope)
      calculate_quantity_distribution(scope)
    end

    def calculate_current_metrics(scope)
      metrics = {}
      
      case self.name
      when 'TeaLot'
        metrics[:average_processing_time] = 72 # Mock calculation
        metrics[:average_shipment_time] = 30 # Mock calculation
        metrics[:traceability_score] = 85 # Mock calculation
      when 'ProcessEvent'
        metrics[:events_per_day] = scope.group_by_day(:occurred_at).count.values.average.round(1)
        metrics[:average_event_duration] = 2 # Mock calculation
      when 'Shipment'
        metrics[:average_shipment_size] = scope.average(:quantity_kg)&.round(1) || 0
        metrics[:shipment_frequency] = scope.group_by_week(:shipped_at).count.values.average.round(1)
      end
      
      metrics
    end

    def generate_tea_lot_recommendations(scope)
      recommendations = []
      
      # Check for lots with low traceability scores
      low_score_lots = scope.select { |lot| lot.traceability_score < 70 }
      if low_score_lots.any?
        recommendations << "#{low_score_lots.count} lots have traceability scores below 70. Consider improving data completeness."
      end
      
      # Check for old lots
      old_lots = scope.where("harvest_date < ?", 1.year.ago)
      if old_lots.any?
        recommendations << "#{old_lots.count} lots are older than 1 year. Consider reviewing inventory."
      end
      
      recommendations
    end

    def generate_process_event_recommendations(scope)
      recommendations = []
      
      # Check for missing events
      incomplete_lots = TeaLot.left_joins(:process_events)
                              .group(:id)
                              .having('COUNT(process_events.id) < 4')
      
      if incomplete_lots.any?
        recommendations << "#{incomplete_lots.count} lots have incomplete processing events."
      end
      
      recommendations
    end

    def generate_shipment_recommendations(scope)
      recommendations = []
      
      # Check for unshipped lots
      unshipped_lots = TeaLot.where.not(status: 'shipped')
      if unshipped_lots.any?
        recommendations << "#{unshipped_lots.count} lots have not been shipped yet."
      end
      
      recommendations
    end
  end

  def generate_individual_report(report_type = :detailed)
    case report_type.to_sym
    when :detailed
      generate_detailed_individual_report
    when :traceability
      generate_traceability_individual_report
    when :history
      generate_history_individual_report
    else
      raise ArgumentError, "Unknown individual report type: #{report_type}"
    end
  end

  private

  def generate_detailed_individual_report
    {
      record_type: self.class.name,
      record_id: id,
      generated_at: Time.current,
      data: as_json,
      metadata: {
        created_at: created_at,
        updated_at: updated_at,
        age_days: ((Time.current - created_at) / 1.day).round(1)
      }
    }
  end

  def generate_traceability_individual_report
    {
      record_type: self.class.name,
      record_id: id,
      generated_at: Time.current,
      traceability_info: traceability_info,
      traceability_score: traceability_score,
      traceability_grade: traceability_grade,
      validation: traceability_validation,
      chain: traceability_chain
    }
  end

  def generate_history_individual_report
    {
      record_type: self.class.name,
      record_id: id,
      generated_at: Time.current,
      current_state: as_json,
      audit_trail: traceability_audit_trail,
      modification_history: traceability_history
    }
  end
end
