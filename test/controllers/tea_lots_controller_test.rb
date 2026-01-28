require "test_helper"

class TeaLotsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get tea_lots_index_url
    assert_response :success
  end

  test "should get show" do
    get tea_lots_show_url
    assert_response :success
  end
end
