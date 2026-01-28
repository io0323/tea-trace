require "test_helper"

class ProcessEventTest < ActiveSupport::TestCase
  test "event_type_label returns Japanese labels" do
    tea_lot = tea_lots(:one)
    
    event = ProcessEvent.new(tea_lot: tea_lot, event_type: "steaming", occurred_at: Time.current)
    assert_equal "蒸熱", event.event_type_label
    
    event = ProcessEvent.new(tea_lot: tea_lot, event_type: "rolling", occurred_at: Time.current)
    assert_equal "揉捻", event.event_type_label
    
    event = ProcessEvent.new(tea_lot: tea_lot, event_type: "drying", occurred_at: Time.current)
    assert_equal "乾燥", event.event_type_label
    
    event = ProcessEvent.new(tea_lot: tea_lot, event_type: "packing", occurred_at: Time.current)
    assert_equal "包装", event.event_type_label
  end

  test "event_type_label returns event_type for unknown types" do
    tea_lot = tea_lots(:one)
    event = ProcessEvent.new(tea_lot: tea_lot, event_type: "unknown", occurred_at: Time.current)
    assert_equal "unknown", event.event_type_label
  end
end
