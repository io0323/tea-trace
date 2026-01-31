class ProcessEventsController < ApplicationController
  before_action :set_tea_lot
  before_action :set_process_event, only: [ :show, :edit, :update, :destroy ]

  def new
    @process_event = @tea_lot.process_events.build
  end

  def create
    @process_event = @tea_lot.process_events.build(process_event_params)

    if @process_event.save
      # Update tea lot status based on events
      update_tea_lot_status

      respond_to do |format|
        format.turbo_stream {
          turbo_stream.replace "modal" do
            render partial: "process_events/success", locals: { process_event: @process_event }
          end
        }
        format.html { redirect_to tea_lot_path(@tea_lot), notice: "工程イベントを追加しました。" }
      end
    else
      respond_to do |format|
        format.turbo_stream {
          turbo_stream.replace "modal" do
            render partial: "process_events/form", locals: { process_event: @process_event }
          end
        }
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def show
  end

  def edit
  end

  def update
    if @process_event.update(process_event_params)
      # Update tea lot status based on events
      update_tea_lot_status

      respond_to do |format|
        format.turbo_stream {
          turbo_stream.replace "modal" do
            render partial: "process_events/success", locals: { process_event: @process_event }
          end
        }
        format.html { redirect_to tea_lot_process_event_path(@tea_lot, @process_event), notice: "工程イベントを更新しました。" }
      end
    else
      respond_to do |format|
        format.turbo_stream {
          turbo_stream.replace "modal" do
            render partial: "process_events/form", locals: { process_event: @process_event }
          end
        }
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    if @process_event.destroy
      # Update tea lot status based on remaining events
      update_tea_lot_status

      respond_to do |format|
        format.turbo_stream {
          turbo_stream.remove "process_event_#{@process_event.id}"
          turbo_stream.update "flash_messages", partial: "shared/flash_messages", locals: { notice: "工程イベントを削除しました。" }
        }
        format.html { redirect_to tea_lot_path(@tea_lot), notice: "工程イベントを削除しました。" }
      end
    else
      respond_to do |format|
        format.turbo_stream {
          turbo_stream.update "flash_messages", partial: "shared/flash_messages", locals: { alert: "工程イベントの削除に失敗しました。" }
        }
        format.html { redirect_to tea_lot_process_event_path(@tea_lot, @process_event), alert: "工程イベントの削除に失敗しました。" }
      end
    end
  end

  private

  def set_tea_lot
    @tea_lot = TeaLot.find(params[:tea_lot_id])
  end

  def set_process_event
    @process_event = @tea_lot.process_events.find(params[:id])
  end

  def process_event_params
    params.require(:process_event).permit(:event_type, :occurred_at, :note)
  end

  def update_tea_lot_status
    events = @tea_lot.process_events.order(:occurred_at)

    if events.where(event_type: "packing").any?
      @tea_lot.update!(status: "shipped")
    elsif events.where(event_type: "drying").any?
      @tea_lot.update!(status: "processing")
    elsif events.any?
      @tea_lot.update!(status: "processing")
    else
      @tea_lot.update!(status: "received")
    end
  end
end
