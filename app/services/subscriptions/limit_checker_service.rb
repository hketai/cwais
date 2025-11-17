class Subscriptions::LimitCheckerService
  pattr_initialize [:account!]

  def can_create_message?
    return true unless account.has_active_subscription?

    plan = account.subscription_plan
    current_count = account.messages.count
    plan.can_create_message?(current_count)
  end

  def can_create_conversation?
    return true unless account.has_active_subscription?

    plan = account.subscription_plan
    current_count = account.conversations.count
    plan.can_create_conversation?(current_count)
  end

  def can_add_agent?
    return true unless account.has_active_subscription?

    plan = account.subscription_plan
    current_count = account.users.count
    plan.can_add_agent?(current_count)
  end

  def can_add_inbox?
    return true unless account.has_active_subscription?

    plan = account.subscription_plan
    current_count = account.inboxes.count
    plan.can_add_inbox?(current_count)
  end

  def check_all_limits
    # Optimize: Load all counts in a single query batch to avoid N+1
    # Use Rails.cache.fetch to cache counts for 1 minute to reduce DB load
    # Cache is only used for the limits display page, not for real-time validations
    cache_key = "account_#{account.id}_usage_counts"
    counts = Rails.cache.fetch(cache_key, expires_in: 1.minute) do
      {
        messages: account.messages.count,
        conversations: account.conversations.count,
        users: account.users.count,
        inboxes: account.inboxes.count
      }
    end

    plan = account.subscription_plan
    {
      messages: {
        allowed: can_create_message?,
        current: counts[:messages],
        limit: plan&.message_limit || 0
      },
      conversations: {
        allowed: can_create_conversation?,
        current: counts[:conversations],
        limit: plan&.conversation_limit || 0
      },
      agents: {
        allowed: can_add_agent?,
        current: counts[:users],
        limit: (plan&.agent_limit || 0).to_i
      },
      inboxes: {
        allowed: can_add_inbox?,
        current: counts[:inboxes],
        limit: (plan&.inbox_limit || 0).to_i
      }
    }
  end

  def validate_message_creation!
    raise Exceptions::LimitExceeded, 'Message limit exceeded' unless can_create_message?
  end

  def validate_conversation_creation!
    raise Exceptions::LimitExceeded, 'Conversation limit exceeded' unless can_create_conversation?
  end

  def validate_agent_addition!
    raise Exceptions::LimitExceeded, 'Agent limit exceeded' unless can_add_agent?
  end

  def validate_inbox_addition!
    raise Exceptions::LimitExceeded, 'Inbox limit exceeded' unless can_add_inbox?
  end
end

