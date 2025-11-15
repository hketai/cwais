class Subscriptions::CancelSubscriptionService
  pattr_initialize [:account!, :options]

  def perform
    validate_account!
    subscription = find_subscription

    ActiveRecord::Base.transaction do
      subscription.cancel!
      handle_immediate_cancellation if options&.dig(:immediate)
      subscription
    end
  end

  private

  def validate_account!
    raise ArgumentError, 'Account is required' if account.blank?
  end

  def find_subscription
    subscription = options&.dig(:subscription_id) ? 
      account.account_subscriptions.find(options[:subscription_id]) : 
      account.current_subscription

    raise ArgumentError, 'No active subscription found' if subscription.blank?
    subscription
  end

  def handle_immediate_cancellation
    # If immediate cancellation, expire the subscription now
    # Otherwise, it will expire at expires_at
    subscription = find_subscription
    subscription.update!(expires_at: Time.current) if options&.dig(:immediate)
  end
end

