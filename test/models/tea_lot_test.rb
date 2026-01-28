require "test_helper"

class TeaLotTest < ActiveSupport::TestCase
  test "formatted_quantity returns properly formatted string" do
    tea_lot = TeaLot.new(lot_code: "TEST-001", origin: "テスト", variety: "テスト", harvest_date: Date.today, quantity_kg: 120.5, status: "received")
    assert_equal "120.5", tea_lot.formatted_quantity
  end

  test "formatted_quantity handles decimal values" do
    tea_lot = TeaLot.new(lot_code: "TEST-002", origin: "テスト", variety: "テスト", harvest_date: Date.today, quantity_kg: 85.333, status: "received")
    assert_equal "85.3", tea_lot.formatted_quantity
  end

  test "formatted_quantity handles integer values" do
    tea_lot = TeaLot.new(lot_code: "TEST-003", origin: "テスト", variety: "テスト", harvest_date: Date.today, quantity_kg: 100.0, status: "received")
    assert_equal "100.0", tea_lot.formatted_quantity
  end
end
