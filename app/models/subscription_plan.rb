# == Schema Information
#
# Table name: subscription_plans
#
#  id                 :bigint           not null, primary key
#  agent_limit        :integer
#  billing_cycle      :string
#  conversation_limit :integer          default(0)
#  description        :text
#  features           :jsonb
#  inbox_limit        :integer
#  is_active          :boolean          default(TRUE), not null
#  is_free            :boolean          default(FALSE), not null
#  message_limit      :integer          default(0)
#  name               :string           not null
#  position           :integer          default(0)
#  price              :decimal(10, 2)   default(0.0)
#  trial_days         :integer
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
# Indexes
#
#  index_subscription_plans_on_is_active  (is_active)
#  index_subscription_plans_on_is_free    (is_free)
#  index_subscription_plans_on_position   (position)
#
class SubscriptionPlan < ApplicationRecord
  has_many :account_subscriptions, dependent: :restrict_with_error
  has_many :accounts, through: :account_subscriptions

  # Custom attribute name for Administrate
  def self.human_attribute_name(attr, options = {})
    case attr.to_sym
    when :is_active
      'Account Panelinde Göster'
    else
      super
    end
  end

  validates :name, presence: true, uniqueness: true
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :message_limit, numericality: { greater_than_or_equal_to: 0 }
  validates :conversation_limit, numericality: { greater_than_or_equal_to: 0 }
  validates :agent_limit, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :inbox_limit, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :active, -> { where(is_active: true) }
  scope :free, -> { where(is_free: true) }
  scope :paid, -> { where(is_free: false) }
  scope :ordered, -> { order(position: :asc, created_at: :desc) }

  store_accessor :features

  def unlimited_messages?
    message_limit.zero?
  end

  def unlimited_conversations?
    conversation_limit.zero?
  end

  def unlimited_agents?
    (agent_limit || 0).to_i.zero?
  end

  def unlimited_inboxes?
    (inbox_limit || 0).to_i.zero?
  end

  def can_create_message?(current_count)
    return true if unlimited_messages?
    current_count < message_limit
  end

  def can_create_conversation?(current_count)
    return true if unlimited_conversations?
    current_count < conversation_limit
  end

  def can_add_agent?(current_count)
    return true if unlimited_agents?
    current_count < (agent_limit || 0).to_i
  end

  def can_add_inbox?(current_count)
    return true if unlimited_inboxes?
    current_count < (inbox_limit || 0).to_i
  end
end

