class AddEventSignatureToSnooEvents < ActiveRecord::Migration[8.1]
  def up
    add_column :snoo_events, :event_signature, :string

    execute <<~SQL
      UPDATE snoo_events
      SET event_signature = md5(
        concat_ws(
          '|',
          coalesce(device_serial, ''),
          coalesce(event_type, ''),
          coalesce(to_char(event_time AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'), ''),
          coalesce(state, ''),
          coalesce(level, ''),
          coalesce(hold::text, ''),
          coalesce(left_clip::text, ''),
          coalesce(right_clip::text, ''),
          coalesce(sticky_white_noise::text, ''),
          coalesce(sw_version, ''),
          coalesce(raw_payload, '')
        )
      )
      WHERE event_signature IS NULL
    SQL

    execute <<~SQL
      DELETE FROM snoo_events newer
      USING snoo_events older
      WHERE newer.id > older.id
        AND newer.event_signature = older.event_signature
    SQL

    change_column_null :snoo_events, :event_signature, false
    add_index :snoo_events, :event_signature, unique: true
  end

  def down
    remove_index :snoo_events, :event_signature
    remove_column :snoo_events, :event_signature
  end
end
