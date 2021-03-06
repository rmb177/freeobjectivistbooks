# Manages creating new Contributions; i.e., paying for donations.
class ContributionsController < ApplicationController
  before_filter :require_login, except: :create
  before_filter :verify_signature, only: :create

  def load_models
    super
    @order = Order.find params[:order_id] if params[:order_id]
  end

  def verify_signature
    @signature = AmazonSignature.new request.request_parameters, request.url
    if !Rails.env.test? && !@signature.valid?
      logger.error "Signature failed using url: #{request.url}, params: #{request.request_parameters}"
      raise "Amazon Payments response signature verification failed"
    end
  end

  def new_payment(options = {})
    AmazonPayment.new options.merge(
      ipn_url: contributions_url,
      return_url: thankyou_contributions_url,
      abandon_url: cancel_contributions_url,
    )
  end

  def test
    @amount = Money.parse(params[:amount] || 10)
    @amazon_payment = AmazonPayment.new(
        amount: @amount,
        reference_id: @current_user.id,
        description: "#{@amount.format} test",
        is_live: false,
        ipn_url: contributions_url,
        return_url: test_contributions_url,
        abandon_url: test_contributions_url(abandoned: true),
    )

    if params[:abandoned].to_bool
      flash.now[:error] = "Test payment abandoned"
    elsif AmazonPayment.success_status?(params['status'])
      flash.now[:notice] = "Payment received: #{params['transactionAmount']}"
    end
  end

  def create_contribution
    return if @signature.sandbox?

    contribution = Contribution.find_or_initialize_from_amazon_ipn params
    return if !contribution

    if @order
      @order.contributions << contribution
    else
      contribution.save!
    end
  end

  def create
    create_contribution
    render nothing: true
  end
end
