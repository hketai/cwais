json.id @subscription.id
json.account_id @subscription.account_id
json.subscription_plan_id @subscription.subscription_plan_id
json.status @subscription.status
json.started_at @subscription.started_at
json.expires_at @subscription.expires_at
json.canceled_at @subscription.canceled_at
json.days_remaining @subscription.days_remaining
json.active @subscription.active?
json.trial @subscription.trial?
json.canceled @subscription.canceled?
json.metadata @subscription.metadata || {}
json.plan do
  json.id @subscription.subscription_plan.id
  json.name @subscription.subscription_plan.name
  json.description @subscription.subscription_plan.description
  json.price @subscription.subscription_plan.price.to_f
  json.message_limit @subscription.subscription_plan.message_limit
  json.conversation_limit @subscription.subscription_plan.conversation_limit
  json.agent_limit @subscription.subscription_plan.agent_limit
  json.inbox_limit @subscription.subscription_plan.inbox_limit
  json.billing_cycle @subscription.subscription_plan.billing_cycle
end

