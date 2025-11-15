class Api::V1::Accounts::SubscriptionPlansController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization

  def index
    @plans = SubscriptionPlan.active.ordered
  rescue StandardError => e
    Rails.logger.error "SubscriptionPlansController#index error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render json: { error: e.message }, status: :internal_server_error
  end

  def show
    @plan = SubscriptionPlan.active.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Plan not found or not active' }, status: :not_found
  rescue StandardError => e
    Rails.logger.error "SubscriptionPlansController#show error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render json: { error: e.message }, status: :internal_server_error
  end
end

