class SuperAdmin::AccountSubscriptionsController < SuperAdmin::ApplicationController
  # Overwrite any of the RESTful controller actions to implement custom behavior
  # For example, you may want to send an email after a subscription is updated.
  
  def update
    Rails.logger.info "AccountSubscription update called for ID: #{requested_resource.id}"
    Rails.logger.info "Params: #{params.inspect}"
    
    if requested_resource.update(resource_params)
      Rails.logger.info "AccountSubscription updated successfully: #{requested_resource.inspect}"
      # Redirect back to the account show page if coming from there
      if params[:return_to_account].present?
        redirect_to [:super_admin, requested_resource.account], notice: translate_with_resource('update.success')
      else
        redirect_to [namespace, requested_resource], notice: translate_with_resource('update.success')
      end
    else
      Rails.logger.error "AccountSubscription update failed: #{requested_resource.errors.full_messages.inspect}"
      render :edit, locals: { page: Administrate::Page::Form.new(dashboard, requested_resource) }, status: :unprocessable_entity
    end
  end
  
  # Override `resource_params` if you want to transform the submitted
  # data before it's persisted.
  def resource_params
    permitted_params = super
    
    Rails.logger.info "AccountSubscription update params: #{permitted_params.inspect}"
    
    # Handle metadata if it's a string (from form)
    if permitted_params[:metadata].is_a?(String)
      begin
        permitted_params[:metadata] = JSON.parse(permitted_params[:metadata])
      rescue JSON::ParserError
        permitted_params[:metadata] = {}
      end
    end
    
    # Handle datetime fields
    %i[started_at expires_at canceled_at].each do |field|
      if permitted_params[field].present? && permitted_params[field].is_a?(String)
        begin
          permitted_params[field] = Time.zone.parse(permitted_params[field])
        rescue ArgumentError
          # Keep original value if parsing fails
        end
      end
    end
    
    Rails.logger.info "AccountSubscription processed params: #{permitted_params.inspect}"
    
    permitted_params
  end
end

