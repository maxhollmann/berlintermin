class AppointmentRequestsController < ApplicationController
  before_action :authenticate_user!

  expose(:appointment_requests) { current_user.appointment_requests }
  expose(:appointment_request, attributes: :appointment_request_params)

  def create
    if appointment_request.save
      CheckForSlotsJob.perform_later
      redirect_to appointment_requests_path, notice: "Request created!"
    else
      render action: :new
    end
  end

  def update
    if appointment_request.save
      redirect_to appointment_requests_path, notice: "Request updated!"
    else
      render action: :edit
    end
  end

  def destroy
    appointment_request.destroy
    redirect_to appointment_requests_path
  end

  private

    def appointment_request_params
      params.require(:appointment_request).permit(
        :name, :email, :phone,
        :location, :deadline,
      )
    end
end
