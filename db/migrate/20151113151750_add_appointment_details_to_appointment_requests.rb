class AddAppointmentDetailsToAppointmentRequests < ActiveRecord::Migration
  def change
    add_column :appointment_requests, :appointment_made_at, :datetime
    add_column :appointment_requests, :appointment_number, :string
    add_column :appointment_requests, :appointment_cancellation_code, :string
  end
end
