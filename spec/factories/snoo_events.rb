FactoryBot.define do
  factory :snoo_event do
    sequence(:device_serial) { |n| "device-#{n}" }
    sequence(:event_type) { |n| "status-#{n}" }
    sequence(:event_signature) { |n| "event-signature-#{n}" }
    sequence(:event_time) { |n| Time.zone.parse("2026-04-10 12:00:00") + n.seconds }
    state { "LEVEL1" }
    level { "1" }
    hold { false }
    left_clip { true }
    right_clip { true }
    sticky_white_noise { false }
    sw_version { "v1.15.05" }
    raw_payload do
      {
        serialNumber: device_serial,
        firmwareVersion: sw_version,
        name: "Puzzle SNOO",
        presenceIoT: { online: true },
        activityState: {
          event: event_type,
          event_time_ms: (event_time.to_f * 1000).to_i,
          left_safety_clip: left_clip ? 1 : 0,
          right_safety_clip: right_clip ? 1 : 0,
          sw_version: sw_version,
          system_state: "normal",
          state_machine: {
            state: state,
            hold: hold ? "on" : "off",
            sticky_white_noise: sticky_white_noise ? "on" : "off",
            audio: "on",
            weaning: "off"
          }
        }
      }.to_json
    end
  end
end
