class CreateAccountSubscriptions < ActiveRecord::Migration[7.1]
  def change
    create_table :account_subscriptions do |t|
      t.bigint :account_id, null: false
      t.bigint :subscription_plan_id, null: false
      t.string :status, default: 'active', null: false
      t.string :iyzico_subscription_id
      t.datetime :started_at, null: false
      t.datetime :expires_at
      t.datetime :canceled_at

      t.timestamps
    end

    add_index :account_subscriptions, :account_id
    add_index :account_subscriptions, :subscription_plan_id
    add_index :account_subscriptions, :status
    add_index :account_subscriptions, :iyzico_subscription_id
    add_index :account_subscriptions, [:account_id, :status]
    add_foreign_key :account_subscriptions, :accounts
    add_foreign_key :account_subscriptions, :subscription_plans
  end
end
