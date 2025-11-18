# == Schema Information
#
# Table name: account_subscriptions
#
#  id                     :bigint           not null, primary key
#  canceled_at            :datetime
#  expires_at             :datetime
#  metadata               :jsonb
#  started_at             :datetime         not null
#  status                 :string           default("active"), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  account_id             :bigint           not null
#  iyzico_subscription_id :string
#  subscription_plan_id   :bigint           not null
#
# Indexes
#
#  index_account_subscriptions_on_account_id              (account_id)
#  index_account_subscriptions_on_account_id_and_status   (account_id,status)
#  index_account_subscriptions_on_iyzico_subscription_id  (iyzico_subscription_id)
#  index_account_subscriptions_on_status                  (status)
#  index_account_subscriptions_on_subscription_plan_id    (subscription_plan_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (subscription_plan_id => subscription_plans.id)
#
class AccountSubscription < ApplicationRecord
  belongs_to :account
  belongs_to :subscription_plan

  validates :status, presence: true, inclusion: { in: %w[active canceled expired trial suspended] }
  validates :started_at, presence: true

  scope :active, -> { where(status: 'active') }
  scope :current, -> { where(status: ['active', 'trial']).where('expires_at IS NULL OR expires_at > ?', Time.current) }
  scope :expired, -> { where('expires_at < ?', Time.current) }
  scope :trial, -> { where(status: 'trial') }

  store_accessor :metadata

  before_validation :set_defaults, on: :create

  def active?
    status == 'active' && (expires_at.nil? || expires_at > Time.current)
  end

  def current?
    # A subscription is current if it's active or trial, not expired, and matches account's current subscription
    (status == 'active' || status == 'trial') && 
    (expires_at.nil? || expires_at > Time.current) &&
    account.current_subscription&.id == id
  end

  # Virtual attribute for Administrate dashboard
  def is_current
    current? ? '✓ Aktif' : ''
  end

  def expired?
    expires_at.present? && expires_at < Time.current
  end

  def trial?
    status == 'trial'
  end

  def canceled?
    status == 'canceled'
  end

  def days_remaining
    return nil if expires_at.nil?
    [(expires_at - Time.current).to_i / 1.day, 0].max
  end

  def cancel!
    update!(
      status: 'canceled',
      canceled_at: Time.current
    )
  end

  def activate!
    update!(
      status: 'active',
      canceled_at: nil
    )
  end

  def expire!
    update!(status: 'expired') if expired?
  end

  def renew!(new_expires_at = nil)
    new_expires_at ||= calculate_next_period_end
    metadata_hash = metadata || {}
    metadata_hash['auto_renew'] = true unless metadata_hash.key?('auto_renew')
    update!(
      status: 'active',
      expires_at: new_expires_at,
      canceled_at: nil,
      metadata: metadata_hash
    )
  end

  def upgrade_to_plan!(new_plan)
    transaction do
      cancel! if active?
      AccountSubscription.create!(
        account: account,
        subscription_plan: new_plan,
        status: 'active',
        started_at: Time.current,
        expires_at: calculate_next_period_end(new_plan),
        metadata: { auto_renew: true }
      )
    end
  end

  private

  def set_defaults
    self.status ||= 'active'
    self.started_at ||= Time.current
    self.metadata ||= {}
    self.metadata['auto_renew'] = true unless metadata.key?('auto_renew')
  end

  def calculate_next_period_end(plan = nil)
    plan ||= subscription_plan
    return nil if plan.billing_cycle.blank?

    case plan.billing_cycle
    when 'monthly'
      (started_at || Time.current) + 1.month
    when 'yearly'
      (started_at || Time.current) + 1.year
    else
      nil
    end
  end
end

