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
end
