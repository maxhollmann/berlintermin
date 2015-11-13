class AppointmentRequest < ActiveRecord::Base
  belongs_to :user

  validates :name, :email, :phone, presence: true

  geocoded_by :location_in_berlin
  after_validation :geocode

  def location_in_berlin
    location + ", Berlin, Germany"
  end
end
