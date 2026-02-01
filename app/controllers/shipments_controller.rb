class ShipmentsController < ApplicationController
  before_action :set_shipment, only: [:show, :edit, :update, :destroy]
  before_action :set_tea_lot, only: [:index, :new, :create]

  def index
    @shipments = @tea_lot.shipments.order(shipped_at: :desc)
  end

  def show
  end

  def new
    @shipment = @tea_lot.shipments.new
  end

  def create
    @shipment = @tea_lot.shipments.new(shipment_params)

    if @shipment.save
      redirect_to [@tea_lot, @shipment], notice: "出荷情報が正常に作成されました。"
    else
      flash[:alert] = @shipment.errors.full_messages.join(", ")
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @shipment.update(shipment_params)
      redirect_to [@tea_lot, @shipment], notice: "出荷情報が正常に更新されました。"
    else
      flash[:alert] = @shipment.errors.full_messages.join(", ")
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @shipment.destroy
    redirect_to tea_lot_shipments_path(@tea_lot), notice: "出荷情報が正常に削除されました。"
  end

  private

  def set_shipment
    @tea_lot = TeaLot.find(params[:tea_lot_id])
    @shipment = @tea_lot.shipments.find(params[:id])
  end

  def set_tea_lot
    @tea_lot = TeaLot.find(params[:tea_lot_id])
  end

  def shipment_params
    params.require(:shipment).permit(:destination, :shipped_at, :quantity_kg, :notes)
  end
end
