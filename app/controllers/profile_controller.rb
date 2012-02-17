class ProfileController < ApplicationController
  before_filter :require_login

  def show
    donations = @current_user.donations.active
    @show_donations = donations.any? || @current_user.pledges.any?
    unsent_donations = donations.not_sent
    @donations = unsent_donations.not_flagged
    @flag_count = unsent_donations.flagged.count
  end
end
