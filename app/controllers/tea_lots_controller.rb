class TeaLotsController < ApplicationController
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
end
