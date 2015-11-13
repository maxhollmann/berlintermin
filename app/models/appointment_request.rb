class AppointmentRequest < ActiveRecord::Base
  belongs_to :user

  validates :name, :email, :phone, presence: true

  geocoded_by :location_in_berlin
  after_validation :geocode

  scope :outstanding, -> { where(appointment_made_at: nil) }

  def location_in_berlin
    location + ", Berlin, Germany"
  end
end
