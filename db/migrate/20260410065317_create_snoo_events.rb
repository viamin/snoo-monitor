class CreateSnooEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :snoo_events do |t|
      t.string :device_serial
      t.string :event_type
      t.string :state
      t.string :level
      t.boolean :hold
      t.boolean :left_clip
      t.boolean :right_clip
      t.boolean :sticky_white_noise
      t.string :sw_version
      t.text :raw_payload
      t.datetime :event_time

      t.timestamps
    end
  end
end
