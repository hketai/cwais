# Subscription Plans Seed
# Run with: rails runner db/seeds_subscription_plans.rb

puts 'Creating subscription plans...'

# Free Plan
free_plan = SubscriptionPlan.find_or_create_by!(name: 'Ücretsiz') do |plan|
  plan.description = 'Başlangıç için ücretsiz plan'
  plan.price = 0.0
  plan.is_free = true
  plan.is_active = true
  plan.message_limit = 1000
  plan.conversation_limit = 100
  plan.agent_limit = 2
  plan.inbox_limit = 2
  plan.billing_cycle = 'monthly'
  plan.trial_days = 0
  plan.position = 1
end

# Basic Plan
basic_plan = SubscriptionPlan.find_or_create_by!(name: 'Temel') do |plan|
  plan.description = 'Küçük işletmeler için temel plan'
  plan.price = 99.0
  plan.is_free = false
  plan.is_active = true
  plan.message_limit = 10000
  plan.conversation_limit = 1000
  plan.agent_limit = 5
  plan.inbox_limit = 5
  plan.billing_cycle = 'monthly'
  plan.trial_days = 14
  plan.position = 2
end

# Professional Plan
professional_plan = SubscriptionPlan.find_or_create_by!(name: 'Profesyonel') do |plan|
  plan.description = 'Büyüyen işletmeler için profesyonel plan'
  plan.price = 299.0
  plan.is_free = false
  plan.is_active = true
  plan.message_limit = 50000
  plan.conversation_limit = 5000
  plan.agent_limit = 20
  plan.inbox_limit = 20
  plan.billing_cycle = 'monthly'
  plan.trial_days = 14
  plan.position = 3
end

# Enterprise Plan
enterprise_plan = SubscriptionPlan.find_or_create_by!(name: 'Kurumsal') do |plan|
  plan.description = 'Büyük işletmeler için sınırsız plan'
  plan.price = 999.0
  plan.is_free = false
  plan.is_active = true
  plan.message_limit = 0 # Unlimited
  plan.conversation_limit = 0 # Unlimited
  plan.agent_limit = 0 # Unlimited
  plan.inbox_limit = 0 # Unlimited
  plan.billing_cycle = 'monthly'
  plan.trial_days = 30
  plan.position = 4
end

puts "Created #{SubscriptionPlan.count} subscription plans"
puts "Plans: #{SubscriptionPlan.pluck(:name).join(', ')}"

