json.limits do
  json.messages do
    json.allowed @limits[:messages][:allowed]
    json.current @limits[:messages][:current]
    json.limit @limits[:messages][:limit]
  end
  json.conversations do
    json.allowed @limits[:conversations][:allowed]
    json.current @limits[:conversations][:current]
    json.limit @limits[:conversations][:limit]
  end
  json.agents do
    json.allowed @limits[:agents][:allowed]
    json.current @limits[:agents][:current]
    json.limit @limits[:agents][:limit]
  end
  json.inboxes do
    json.allowed @limits[:inboxes][:allowed]
    json.current @limits[:inboxes][:current]
    json.limit @limits[:inboxes][:limit]
  end
end
json.usage @usage
json.subscription do
  if @subscription
    json.id @subscription.id
    json.status @subscription.status
    json.expires_at @subscription.expires_at
    json.plan do
      json.id @subscription.subscription_plan.id
      json.name @subscription.subscription_plan.name
    end
  else
    json.nil!
  end
end

