require "test_helper"

class ProcessEventsControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get process_events_new_url
    assert_response :success
  end

  test "should get create" do
    get process_events_create_url
    assert_response :success
  end
end
