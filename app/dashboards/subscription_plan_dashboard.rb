require 'administrate/base_dashboard'

class SubscriptionPlanDashboard < Administrate::BaseDashboard
  # ATTRIBUTE_TYPES
  # a hash that describes the type of each of the model's fields.
  #
  # Each different type represents an Administrate::Field object,
  # which determines how the attribute is displayed
  # on pages throughout the dashboard.
  ATTRIBUTE_TYPES = {
    id: Field::Number.with_options(searchable: true),
    name: Field::String.with_options(searchable: true),
    description: Field::Text,
    price: Field::Number.with_options(decimals: 2),
    is_free: Field::Boolean,
    is_active: Field::Select.with_options(
      collection: [['Göster', true], ['Gizle', false]]
    ),
    message_limit: Field::Number,
    conversation_limit: Field::Number,
    agent_limit: Field::Number,
    inbox_limit: Field::Number,
    billing_cycle: Field::Select.with_options(
      collection: ['', 'monthly', 'yearly']
    ),
    trial_days: Field::Number,
    position: Field::Number,
    features: SerializedField,
    account_subscriptions: Field::HasMany,
    accounts: Field::HasMany,
    created_at: Field::DateTime,
    updated_at: Field::DateTime,
  }.freeze

  # COLLECTION_ATTRIBUTES
  # an array of attributes that will be displayed on the model's index page.
  #
  # By default, it's limited to four items to reduce clutter on index pages.
  # Feel free to add, remove, or rearrange items.
  COLLECTION_ATTRIBUTES = %i[
    id
    name
    price
    is_free
    is_active
    position
  ].freeze

  # SHOW_PAGE_ATTRIBUTES
  # an array of attributes that will be displayed on the model's show page.
  SHOW_PAGE_ATTRIBUTES = %i[
    id
    name
    description
    price
    is_free
    is_active
    message_limit
    conversation_limit
    agent_limit
    inbox_limit
    billing_cycle
    trial_days
    position
    features
    account_subscriptions
    created_at
    updated_at
  ].freeze

  # FORM_ATTRIBUTES
  # an array of attributes that will be displayed
  # on the model's form (`new` and `edit`) pages.
  FORM_ATTRIBUTES = %i[
    name
    description
    price
    is_free
    is_active
    message_limit
    conversation_limit
    agent_limit
    inbox_limit
    billing_cycle
    trial_days
    position
  ].freeze

  # COLLECTION_FILTERS
  # a hash that defines filters that can be used while searching via the search
  # field of the dashboard.
  #
  # For example to add an option to search for open resources by typing "open:"
  # in the search field:
  #
  #   COLLECTION_FILTERS = {
  #     open: ->(resources) { resources.where(open: true) }
  #   }.freeze
  COLLECTION_FILTERS = {}.freeze

  # Overwrite this method to customize how subscription plans are displayed
  # across all pages of the admin dashboard.
  #
  # def display_resource(subscription_plan)
  #   "SubscriptionPlan ##{subscription_plan.id}"
  # end
end

