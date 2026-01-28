require "test_helper"

class ProcessEventsControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    tea_lot = tea_lots(:one)
    get new_tea_lot_process_event_path(tea_lot)
    assert_response :success
  end
end
