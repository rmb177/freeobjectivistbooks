# Manages Orders.
class OrdersController < ApplicationController
  def load_models
    super
    @donations = Donation.find_all_by_id params[:donation_ids] if params[:donation_ids]
  end

  def allowed_users
    if @order
      @order.user
    elsif @donations
      users = @donations.map {|d| d.user}.uniq
      raise ForbiddenException if users.size > 1  # should never happen
      users
    end
  end

  def create
    @order = Order.create! user: @current_user, donations: @donations
    redirect_to @order
  end
end