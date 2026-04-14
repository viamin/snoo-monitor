require "rails_helper"

RSpec.describe SnooEvent, type: :model do
  describe ".attributes_from_payload" do
    it "normalizes state machine values into event attributes" do
      payload = build_snoo_payload(
        "activityState" => {
          "event" => "cry",
          "event_time_ms" => 1_776_064_090_000,
          "state_machine" => {
            "state" => "LEVEL2",
            "hold" => "on",
            "sticky_white_noise" => "on"
          }
        }
      )

      attributes = described_class.attributes_from_payload(payload, device_serial_fallback: "fallback-device")

      expect(attributes).to include(
        device_serial: "7771191058523701",
        event_type: "cry",
        state: "LEVEL2",
        level: "2",
        hold: true,
        sticky_white_noise: true,
        sw_version: "v1.15.05"
      )
      expect(attributes[:event_time]).to be_a(Time)
    end
  end

  describe ".persist_payload!" do
    it "deduplicates identical payloads by signature" do
      payload = build_snoo_payload

      first_event, first_created = described_class.persist_payload!(payload)
      second_event, second_created = described_class.persist_payload!(payload)

      expect(first_created).to be(true)
      expect(second_created).to be(false)
      expect(second_event.id).to eq(first_event.id)
      expect(described_class.count).to eq(1)
    end
  end

  describe "#resolved_state" do
    it "falls back to the raw payload when normalized columns are blank" do
      event = build(
        :snoo_event,
        state: nil,
        level: nil,
        hold: nil,
        sticky_white_noise: nil,
        raw_payload: build_snoo_payload(
          "activityState" => {
            "state_machine" => {
              "state" => "LEVEL3",
              "hold" => "on",
              "sticky_white_noise" => "on"
            }
          }
        ).to_json
      )

      expect(event.resolved_state).to eq("LEVEL3")
      expect(event.resolved_level).to eq("3")
      expect(event.resolved_hold).to be(true)
      expect(event.resolved_sticky_white_noise).to be(true)
    end
  end
end
