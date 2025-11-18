json.array! @plans do |plan|
  json.id plan.id
  json.name plan.name
  json.description plan.description
  json.price plan.price.to_f
  json.is_free plan.is_free
  json.is_active plan.is_active
  json.message_limit plan.message_limit
  json.conversation_limit plan.conversation_limit
  json.agent_limit plan.agent_limit
  json.inbox_limit plan.inbox_limit
  json.billing_cycle plan.billing_cycle
  json.trial_days plan.trial_days
  json.position plan.position
  json.unlimited_messages plan.unlimited_messages?
  json.unlimited_conversations plan.unlimited_conversations?
  json.unlimited_agents plan.unlimited_agents?
  json.unlimited_inboxes plan.unlimited_inboxes?
end

