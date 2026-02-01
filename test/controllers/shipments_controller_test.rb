require "test_helper"

class ShipmentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @tea_lot = tea_lots(:one)
    @shipment = shipments(:one)
  end

  test "should get index" do
    get tea_lot_shipments_url(@tea_lot)
    assert_response :success
  end

  test "should get new" do
    get new_tea_lot_shipment_url(@tea_lot)
    assert_response :success
  end

  test "should create shipment" do
    assert_difference("Shipment.count") do
      post tea_lot_shipments_url(@tea_lot), params: {
        shipment: {
          destination: "東京配送センター",
          shipped_at: 1.day.from_now.to_date,
          quantity_kg: 50.5,
          notes: "新しい出荷情報"
        }
      }
    end

    assert_redirected_to tea_lot_shipment_url(@tea_lot, Shipment.last)
    assert_equal "出荷情報が正常に作成されました。", flash[:notice]
  end

  test "should not create shipment with invalid data" do
    assert_no_difference("Shipment.count") do
      post tea_lot_shipments_url(@tea_lot), params: {
        shipment: {
          destination: "",
          shipped_at: "",
          quantity_kg: 0,
          notes: ""
        }
      }
    end

    assert_response :unprocessable_entity
    assert_not_nil flash[:alert]
  end

  test "should show shipment" do
    get tea_lot_shipment_url(@tea_lot, @shipment)
    assert_response :success
  end

  test "should get edit" do
    get edit_tea_lot_shipment_url(@tea_lot, @shipment)
    assert_response :success
  end

  test "should update shipment" do
    patch tea_lot_shipment_url(@tea_lot, @shipment), params: {
      shipment: {
        destination: "更新された出荷先",
        shipped_at: 2.days.from_now.to_date,
        quantity_kg: 75.0,
        notes: "更新された備考"
      }
    }

    assert_redirected_to tea_lot_shipment_url(@tea_lot, @shipment)
    assert_equal "出荷情報が正常に更新されました。", flash[:notice]

    @shipment.reload
    assert_equal "更新された出荷先", @shipment.destination
    assert_equal 75.0, @shipment.quantity_kg
  end

  test "should not update shipment with invalid data" do
    original_destination = @shipment.destination

    patch tea_lot_shipment_url(@tea_lot, @shipment), params: {
      shipment: {
        destination: "",
        shipped_at: "",
        quantity_kg: 0
      }
    }

    assert_response :unprocessable_entity
    assert_not_nil flash[:alert]

    @shipment.reload
    assert_equal original_destination, @shipment.destination
  end

  test "should destroy shipment" do
    assert_difference("Shipment.count", -1) do
      delete tea_lot_shipment_url(@tea_lot, @shipment)
    end

    assert_redirected_to tea_lot_shipments_url(@tea_lot)
    assert_equal "出荷情報が正常に削除されました。", flash[:notice]
  end
end
