class AddFeaturesToSubscriptionPlans < ActiveRecord::Migration[7.1]
  def change
    add_column :subscription_plans, :features, :jsonb
    add_column :subscription_plans, :agent_limit, :integer
    add_column :subscription_plans, :inbox_limit, :integer
    add_column :subscription_plans, :billing_cycle, :string
    add_column :subscription_plans, :trial_days, :integer
  end
end
