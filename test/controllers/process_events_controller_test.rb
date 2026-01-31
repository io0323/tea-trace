require "test_helper"

class ProcessEventsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @tea_lot = tea_lots(:one)
    @process_event = @tea_lot.process_events.create!(
      event_type: "steaming",
      occurred_at: 1.hour.ago,
      note: "テスト工程"
    )
  end

  test "should get new" do
    get new_tea_lot_process_event_path(@tea_lot)
    assert_response :success
  end

  test "should create process_event" do
    assert_difference("ProcessEvent.count") do
      post tea_lot_process_events_path(@tea_lot), params: {
        process_event: {
          event_type: "rolling",
          occurred_at: Time.current,
          note: "新しい工程"
        }
      }
    end

    assert_redirected_to tea_lot_path(@tea_lot)
    assert_equal "工程イベントを追加しました。", flash[:notice]
  end

  test "should not create process_event with invalid data" do
    assert_no_difference("ProcessEvent.count") do
      post tea_lot_process_events_path(@tea_lot), params: {
        process_event: {
          event_type: "",
          occurred_at: "",
          note: ""
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "should show process_event" do
    get tea_lot_process_event_path(@tea_lot, @process_event)
    assert_response :success
  end

  test "should get edit" do
    get edit_tea_lot_process_event_path(@tea_lot, @process_event)
    assert_response :success
  end

  test "should update process_event" do
    patch tea_lot_process_event_path(@tea_lot, @process_event), params: {
      process_event: {
        event_type: "drying",
        note: "更新された工程"
      }
    }

    assert_redirected_to tea_lot_process_event_path(@tea_lot, @process_event)
    assert_equal "工程イベントを更新しました。", flash[:notice]
    @process_event.reload
    assert_equal "drying", @process_event.event_type
    assert_equal "更新された工程", @process_event.note
  end

  test "should not update process_event with invalid data" do
    original_event_type = @process_event.event_type

    patch tea_lot_process_event_path(@tea_lot, @process_event), params: {
      process_event: {
        event_type: "",
        note: ""
      }
    }

    assert_response :unprocessable_entity
    @process_event.reload
    assert_equal original_event_type, @process_event.event_type
  end

  test "should destroy process_event" do
    assert_difference("ProcessEvent.count", -1) do
      delete tea_lot_process_event_path(@tea_lot, @process_event)
    end

    assert_redirected_to tea_lot_path(@tea_lot)
    assert_equal "工程イベントを削除しました。", flash[:notice]
  end

  test "should update tea lot status when process_event is created" do
    @tea_lot.update!(status: "received")

    post tea_lot_process_events_path(@tea_lot), params: {
      process_event: {
        event_type: "drying",
        occurred_at: Time.current,
        note: "乾燥工程"
      }
    }

    @tea_lot.reload
    assert_equal "processing", @tea_lot.status
  end

  test "should update tea lot status to shipped when packing is added" do
    @tea_lot.update!(status: "processing")

    post tea_lot_process_events_path(@tea_lot), params: {
      process_event: {
        event_type: "packing",
        occurred_at: Time.current,
        note: "包装工程"
      }
    }

    @tea_lot.reload
    assert_equal "shipped", @tea_lot.status
  end

  test "should update tea lot status to received when all events are deleted" do
    # Create multiple events
    @tea_lot.process_events.create!(
      event_type: "rolling",
      occurred_at: 30.minutes.ago
    )

    # Delete all events
    @tea_lot.process_events.each do |event|
      delete tea_lot_process_event_path(@tea_lot, event)
    end

    @tea_lot.reload
    assert_equal "received", @tea_lot.status
  end
end
