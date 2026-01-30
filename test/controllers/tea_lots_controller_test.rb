require "test_helper"

class TeaLotsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get tea_lots_path
    assert_response :success
  end

  test "should get show" do
    tea_lot = tea_lots(:one)
    get tea_lot_path(tea_lot)
    assert_response :success
  end

  test "should get new" do
    get new_tea_lot_path
    assert_response :success
  end

  test "should create tea_lot" do
    assert_difference("TeaLot.count") do
      post tea_lots_path, params: {
        tea_lot: {
          lot_code: "TL-TEST-001",
          origin: "テスト産地",
          variety: "テスト品種",
          harvest_date: Date.today,
          quantity_kg: 100.5,
          status: "received"
        }
      }
    end

    assert_redirected_to tea_lot_path(TeaLot.last)
    assert_equal "茶葉ロットが正常に作成されました。", flash[:notice]
  end

  test "should not create tea_lot with invalid data" do
    assert_no_difference("TeaLot.count") do
      post tea_lots_path, params: {
        tea_lot: {
          lot_code: "",
          origin: "",
          variety: "",
          harvest_date: "",
          quantity_kg: 0,
          status: ""
        }
      }
    end

    assert_response :unprocessable_entity
    assert_not_nil flash[:alert]
  end

  test "should get edit" do
    tea_lot = tea_lots(:one)
    get edit_tea_lot_path(tea_lot)
    assert_response :success
  end

  test "should update tea_lot" do
    tea_lot = tea_lots(:one)
    patch tea_lot_path(tea_lot), params: {
      tea_lot: {
        origin: "更新された産地",
        quantity_kg: 150.0
      }
    }

    assert_redirected_to tea_lot_path(tea_lot)
    assert_equal "茶葉ロットが正常に更新されました。", flash[:notice]
    tea_lot.reload
    assert_equal "更新された産地", tea_lot.origin
    assert_equal 150.0, tea_lot.quantity_kg
  end

  test "should not update tea_lot with invalid data" do
    tea_lot = tea_lots(:one)
    original_origin = tea_lot.origin
    
    patch tea_lot_path(tea_lot), params: {
      tea_lot: {
        lot_code: "",
        origin: ""
      }
    }

    assert_response :unprocessable_entity
    assert_not_nil flash[:alert]
    tea_lot.reload
    assert_equal original_origin, tea_lot.origin
  end

  test "should destroy tea_lot" do
    tea_lot = tea_lots(:one)
    
    assert_difference("TeaLot.count", -1) do
      delete tea_lot_path(tea_lot)
    end

    assert_redirected_to tea_lots_path
    assert_equal "茶葉ロットが正常に削除されました。", flash[:notice]
  end

  test "should not destroy tea_lot with process events" do
    tea_lot = tea_lots(:one)
    # Create a process event for this tea lot
    ProcessEvent.create!(
      tea_lot: tea_lot,
      event_type: "steaming",
      occurred_at: Time.current
    )

    assert_no_difference("TeaLot.count") do
      delete tea_lot_path(tea_lot)
    end

    assert_redirected_to tea_lot_path(tea_lot)
    assert_equal "ロットの削除に失敗しました。", flash[:alert]
  end
end
