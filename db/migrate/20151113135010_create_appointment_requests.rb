class CreateAppointmentRequests < ActiveRecord::Migration
  def change
    create_table :appointment_requests do |t|
      t.belongs_to :user, index: true
      t.string :name, null: false
      t.string :email, null: false
      t.string :phone, null: false
      t.string :location, null: false
      t.float :latitude
      t.float :longitude
      t.integer :max_distance
      t.datetime :deadline

      t.timestamps null: false
    end
  end
end
