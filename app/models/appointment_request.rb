class AppointmentRequest < ActiveRecord::Base
  belongs_to :user

  validates :name, :email, :phone, presence: true

  geocoded_by :location_in_berlin
  after_validation :geocode

  default_scope             ->       { order(created_at: :asc) }
  scope :outstanding,       ->       { where(appointment_made_at: nil) }
  scope :matching_deadline, ->(date) { where("deadline >= ?", date.beginning_of_day) }

  def location_in_berlin
    location + ", Berlin, Germany"
  end
end
