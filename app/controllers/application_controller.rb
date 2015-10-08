class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  include Pundit

  layout :layout_by_resource

  decent_configuration do
    strategy DecentExposure::StrongParametersStrategy
  end

  rescue_from ActiveRecord::RecordNotFound do
    render :not_found
  end

  def layout_by_resource
    if devise_controller?
      "devise"
    else
      "application"
    end
  end
end
