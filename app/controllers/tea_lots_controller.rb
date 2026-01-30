class TeaLotsController < ApplicationController
  before_action :set_tea_lot, only: [:show, :edit, :update, :destroy]

  def index
    @tea_lots = TeaLot.includes(:process_events, :shipments)

    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @tea_lots = @tea_lots.where("lot_code ILIKE ? OR origin ILIKE ?", search_term, search_term)
    end

    @tea_lots = @tea_lots.order(harvest_date: :desc)
  end

  def show
    @tea_lot = TeaLot.includes(process_events: :tea_lot, shipments: :tea_lot).find(params[:id])
  end

  def new
    @tea_lot = TeaLot.new
  end

  def create
    @tea_lot = TeaLot.new(tea_lot_params)
    
    if @tea_lot.save
      redirect_to @tea_lot, notice: "茶葉ロットが正常に作成されました。"
    else
      flash.now[:alert] = "ロットの作成に失敗しました。"
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @tea_lot.update(tea_lot_params)
      redirect_to @tea_lot, notice: "茶葉ロットが正常に更新されました。"
    else
      flash.now[:alert] = "ロットの更新に失敗しました。"
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @tea_lot.destroy
      redirect_to tea_lots_path, notice: "茶葉ロットが正常に削除されました。"
    else
      redirect_to @tea_lot, alert: "ロットの削除に失敗しました。"
    end
  end

  private

  def set_tea_lot
    @tea_lot = TeaLot.find(params[:id])
  end

  def tea_lot_params
    params.require(:tea_lot).permit(:lot_code, :origin, :variety, :harvest_date, :quantity_kg, :status)
  end
end
