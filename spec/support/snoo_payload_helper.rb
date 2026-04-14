module SnooPayloadHelper
  def build_snoo_payload(overrides = {})
    base = {
      "serialNumber" => "7771191058523701",
      "firmwareVersion" => "v1.15.05",
      "name" => "Puzzle SNOO",
      "presenceIoT" => { "online" => true },
      "activityState" => {
        "event" => "command",
        "event_time_ms" => 1_776_064_087_028,
        "left_safety_clip" => 1,
        "right_safety_clip" => 1,
        "sw_version" => "v1.15.05",
        "system_state" => "normal",
        "state_machine" => {
          "audio" => "on",
          "hold" => "off",
          "state" => "LEVEL1",
          "sticky_white_noise" => "off",
          "weaning" => "off"
        }
      }
    }

    base.deep_merge(overrides)
  end
end
