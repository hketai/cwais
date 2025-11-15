class AddMetadataToAccountSubscriptions < ActiveRecord::Migration[7.1]
  def change
    add_column :account_subscriptions, :metadata, :jsonb
  end
end
