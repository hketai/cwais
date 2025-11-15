class Subscriptions::UpgradeSubscriptionService
  pattr_initialize [:account!, :new_plan!, :options]

  def perform
    validate_account!
    validate_new_plan!
    validate_upgrade!

    ActiveRecord::Base.transaction do
      old_subscription = account.current_subscription
      new_subscription = create_new_subscription
      handle_proration if options&.dig(:prorate)
      new_subscription
    end
  end

  private

  def validate_account!
    raise ArgumentError, 'Account is required' if account.blank?
  end

  def validate_new_plan!
    raise ArgumentError, 'New subscription plan is required' if new_plan.blank?
    raise ArgumentError, 'Subscription plan is not active' unless new_plan.is_active?
  end

  def validate_upgrade!
    current_plan = account.subscription_plan
    return if current_plan.blank?

    # Allow upgrade/downgrade, but you can add validation here
    # For example: only allow upgrade, not downgrade
    if options&.dig(:only_upgrade)
      raise ArgumentError, 'Can only upgrade, not downgrade' if new_plan.price < current_plan.price
    end
  end

  def create_new_subscription
    Subscriptions::CreateSubscriptionService.new(
      account: account,
      subscription_plan: new_plan,
      options: options.merge(cancel_existing: true)
    ).perform
  end

  def handle_proration
    # Implement proration logic if needed
    # Calculate remaining days and adjust pricing
  end
end

