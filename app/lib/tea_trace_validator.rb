module TeaTraceValidator
  extend ActiveSupport::Concern

  class_methods do
    def validate_lot_code_format(lot_code)
      # Format: TL-YYYY-NNN (e.g., TL-2024-001)
      pattern = /\ATL-\d{4}-\d{3}\z/
      
      {
        valid: lot_code.match?(pattern),
        pattern_description: "TL-YYYY-NNN形式（例: TL-2024-001）",
        examples: ["TL-2024-001", "TL-2023-999", "TL-2025-123"]
      }
    end

    def validate_harvest_date(harvest_date)
      return { valid: false, error: "収穫日は必須です" } if harvest_date.blank?
      
      today = Date.current
      future_limit = today + 1.year
      
      if harvest_date > today
        { valid: false, error: "収穫日は未来の日付にできません" }
      elsif harvest_date < today - 2.year
        { valid: false, error: "収穫日は2年以上前の日付にできません" }
      else
        { valid: true }
      end
    end

    def validate_quantity_range(quantity_kg)
      return { valid: false, error: "数量は必須です" } if quantity_kg.blank?
      
      if quantity_kg <= 0
        { valid: false, error: "数量は0より大きい値である必要があります" }
      elsif quantity_kg > 10000
        { valid: false, error: "数量は10,000kgを超えることはできません" }
      else
        { valid: true }
      end
    end

    def validate_origin_format(origin)
      return { valid: false, error: "産地は必須です" } if origin.blank?
      
      if origin.length < 2
        { valid: false, error: "産地は2文字以上である必要があります" }
      elsif origin.length > 50
        { valid: false, error: "産地は50文字以内である必要があります" }
      else
        { valid: true }
      end
    end

    def validate_variety_format(variety)
      return { valid: false, error: "品種は必須です" } if variety.blank?
      
      valid_varieties = %w[やぶきた さやまかおり 玉露 ほうじ茶 煎茶 かぶせ 抹茶 番茶]
      
      unless valid_varieties.include?(variety)
        { 
          valid: false, 
          error: "無効な品種です",
          valid_options: valid_varieties
        }
      else
        { valid: true }
      end
    end

    def validate_event_sequence(tea_lot, event_type)
      existing_events = tea_lot.process_events.order(:occurred_at).pluck(:event_type)
      
      # Define valid sequences
      valid_sequences = [
        %w[steaming],
        %w[steaming rolling],
        %w[steaming rolling drying],
        %w[steaming rolling drying packing]
      ]
      
      # Check if the new event type creates a valid sequence
      new_sequence = existing_events + [event_type]
      new_sequence.uniq!
      
      # Sort according to expected order
      expected_order = %w[steaming rolling drying packing]
      sorted_sequence = new_sequence.sort_by { |e| expected_order.index(e) || 999 }
      
      # Check if the sorted sequence matches any valid sequence prefix
      valid_sequences.any? do |valid_seq|
        sorted_sequence[0...valid_seq.length] == valid_seq
      end
    end

    def validate_shipment_date(tea_lot, shipped_at)
      harvest_date = tea_lot.harvest_date
      
      if shipped_at < harvest_date
        { valid: false, error: "出荷日は収穫日より後である必要があります" }
      elsif shipped_at > Date.current + 1.month
        { valid: false, error: "出荷日は1ヶ月以上未来の日付にできません" }
      else
        { valid: true }
      end
    end

    def validate_shipment_quantity(tea_lot, quantity_kg)
      available_quantity = tea_lot.quantity_kg - tea_lot.shipments.sum(:quantity_kg)
      
      if quantity_kg <= 0
        { valid: false, error: "出荷量は0より大きい値である必要があります" }
      elsif quantity_kg > available_quantity
        { 
          valid: false, 
          error: "出荷量が利用可能量を超えています。利用可能量: #{available_quantity}kg" 
        }
      else
        { valid: true }
      end
    end

    def validate_event_datetime(tea_lot, occurred_at)
      harvest_date = tea_lot.harvest_date
      
      if occurred_at.to_date < harvest_date
        { valid: false, error: "工程日時は収穫日より後である必要があります" }
      elsif occurred_at > Time.current + 1.day
        { valid: false, error: "工程日時は1日以上未来の時刻にできません" }
      else
        { valid: true }
      end
    end

    def comprehensive_tea_lot_validation(tea_lot_params)
      errors = []
      warnings = []
      
      # Validate lot code
      lot_code_validation = validate_lot_code_format(tea_lot_params[:lot_code])
      errors << lot_code_validation[:error] unless lot_code_validation[:valid]
      
      # Validate harvest date
      harvest_validation = validate_harvest_date(tea_lot_params[:harvest_date])
      errors << harvest_validation[:error] unless harvest_validation[:valid]
      
      # Validate quantity
      quantity_validation = validate_quantity_range(tea_lot_params[:quantity_kg])
      errors << quantity_validation[:error] unless quantity_validation[:valid]
      
      # Validate origin
      origin_validation = validate_origin_format(tea_lot_params[:origin])
      errors << origin_validation[:error] unless origin_validation[:valid]
      
      # Validate variety
      variety_validation = validate_variety_format(tea_lot_params[:variety])
      if variety_validation[:valid]
        warnings << "品種 '#{tea_lot_params[:variety]}' が選択されました" if tea_lot_params[:variety].present?
      else
        errors << variety_validation[:error]
      end
      
      # Business logic warnings
      if tea_lot_params[:quantity_kg].to_f > 1000
        warnings << "大量のロット（#{tea_lot_params[:quantity_kg]}kg）が登録されました"
      end
      
      if tea_lot_params[:harvest_date].present?
        days_since_harvest = (Date.current - tea_lot_params[:harvest_date]).to_i
        if days_since_harvest > 365
          warnings << "1年以上前の収穫日が指定されました（#{days_since_harvest}日前）"
        end
      end
      
      {
        valid: errors.empty?,
        errors: errors,
        warnings: warnings
      }
    end

    def validate_business_rules(tea_lot, action, params = {})
      case action
      when :create_shipment
        validate_shipment_creation(tea_lot, params)
      when :create_event
        validate_event_creation(tea_lot, params)
      when :update_status
        validate_status_update(tea_lot, params[:new_status])
      else
        { valid: true }
      end
    end

    private

    def validate_shipment_creation(tea_lot, params)
      errors = []
      
      # Check if lot can be shipped
      if tea_lot.status == 'received'
        errors << "受入済のロットは出荷できません。まず加工工程を完了させてください。"
      end
      
      # Validate shipment quantity
      quantity_validation = validate_shipment_quantity(tea_lot, params[:quantity_kg])
      errors << quantity_validation[:error] unless quantity_validation[:valid]
      
      # Validate shipment date
      date_validation = validate_shipment_date(tea_lot, params[:shipped_at])
      errors << date_validation[:error] unless date_validation[:valid]
      
      {
        valid: errors.empty?,
        errors: errors
      }
    end

    def validate_event_creation(tea_lot, params)
      errors = []
      
      # Validate event datetime
      datetime_validation = validate_event_datetime(tea_lot, params[:occurred_at])
      errors << datetime_validation[:error] unless datetime_validation[:valid]
      
      # Validate event sequence
      unless validate_event_sequence(tea_lot, params[:event_type])
        errors << "無効な工程シーケンスです。工程は「蒸し→揉み→乾燥→包装」の順序で実行する必要があります。"
      end
      
      {
        valid: errors.empty?,
        errors: errors
      }
    end

    def validate_status_update(tea_lot, new_status)
      errors = []
      
      case new_status
      when 'processing'
        unless tea_lot.process_events.where(event_type: 'steaming').exists?
          errors << "加工中ステータスに変更するには、少なくとも蒸し工程が完了している必要があります。"
        end
      when 'shipped'
        unless tea_lot.process_events.where(event_type: 'packing').exists?
          errors << "出荷済ステータスに変更するには、包装工程が完了している必要があります。"
        end
      end
      
      {
        valid: errors.empty?,
        errors: errors
      }
    end
  end
end
