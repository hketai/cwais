require 'administrate/field/base'

class SubscriptionPlanField < Administrate::Field::Base
  def to_s
    return 'No plan' if data.blank?
    data.name
  end

  def current_plan
    return nil if data.blank?
    data
  end

  def account
    resource
  end
end

