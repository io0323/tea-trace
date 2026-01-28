class ProcessEventsController < ApplicationController
  before_action :set_tea_lot

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

  private

  def set_tea_lot
    @tea_lot = TeaLot.find(params[:tea_lot_id])
  end

  def process_event_params
    params.require(:process_event).permit(:event_type, :occurred_at, :note)
  end

  def update_tea_lot_status
    events = @tea_lot.process_events.order(:occurred_at)
    
    if events.where(event_type: 'packing').any?
      @tea_lot.update!(status: 'shipped')
    elsif events.where(event_type: 'drying').any?
      @tea_lot.update!(status: 'processing')
    else
      @tea_lot.update!(status: 'processing')
    end
  end
end
