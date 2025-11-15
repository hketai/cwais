class Api::V1::Accounts::SubscriptionsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization
  before_action :load_subscription, only: [:show, :update, :cancel]

  def index
    @subscriptions = Current.account.account_subscriptions.includes(:subscription_plan).order(created_at: :desc)
  rescue StandardError => e
    Rails.logger.error "SubscriptionsController#index error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render json: { error: e.message }, status: :internal_server_error
  end

  def show
    # @subscription is loaded by before_action
  end

  def create
    plan = SubscriptionPlan.find(subscription_params[:subscription_plan_id])
    
    @subscription = Subscriptions::CreateSubscriptionService.new(
      account: Current.account,
      subscription_plan: plan,
      options: subscription_params[:options] || {}
    ).perform

    render :show, status: :created
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def update
    new_plan = SubscriptionPlan.find(subscription_params[:subscription_plan_id])
    
    @subscription = Subscriptions::UpgradeSubscriptionService.new(
      account: Current.account,
      new_plan: new_plan,
      options: subscription_params[:options] || {}
    ).perform

    render :show
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def cancel
    @subscription = Subscriptions::CancelSubscriptionService.new(
      account: Current.account,
      options: { subscription_id: @subscription.id, immediate: params[:immediate] }
    ).perform

    render :show
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def current
    # Optimize: Eager load subscription_plan to avoid N+1 queries
    @subscription = Current.account.account_subscriptions
                             .includes(:subscription_plan)
                             .current
                             .first
    if @subscription.blank?
      render json: { error: 'No active subscription found' }, status: :not_found
    end
  rescue StandardError => e
    Rails.logger.error "SubscriptionsController#current error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render json: { error: e.message }, status: :internal_server_error
  end

  def limits
    # Optimize: Eager load subscription and plan to avoid N+1 queries
    account = Current.account
    account = Account.includes(account_subscriptions: :subscription_plan).find(account.id)
    
    checker = Subscriptions::LimitCheckerService.new(account: account)
    @limits = checker.check_all_limits
    @usage = account.usage_limits
    @subscription = account.current_subscription
  rescue StandardError => e
    Rails.logger.error "SubscriptionsController#limits error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render json: { error: e.message }, status: :internal_server_error
  end

  private

  def load_subscription
    @subscription = Current.account.account_subscriptions.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Subscription not found' }, status: :not_found
  end

  def subscription_params
    params.require(:subscription).permit(:subscription_plan_id, options: {})
  end
end

