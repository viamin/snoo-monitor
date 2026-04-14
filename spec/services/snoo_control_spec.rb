require "rails_helper"

RSpec.describe SnooControl do
  let(:initial_device) do
    build_snoo_payload(
      "serialNumber" => "device-123",
      "awsIoT" => { "thingName" => "thing-123", "clientEndpoint" => "endpoint.iot.test" }
    )
  end
  let(:auth) do
    instance_double(
      SnooAuth,
      id_token: "id-token",
      token_expired?: false
    )
  end
  let(:mqtt_client) { instance_double(SnooMqttCommandClient, publish!: { "ok" => true }) }

  before do
    allow(SnooMqttCommandClient).to receive(:new).and_return(mqtt_client)
    allow(auth).to receive(:refresh!)
  end

  describe "#change_level!" do
    it "publishes a go_to_state command for the adjacent level and persists the refreshed payload" do
      updated_device = build_snoo_payload(
        "serialNumber" => "device-123",
        "awsIoT" => { "thingName" => "thing-123", "clientEndpoint" => "endpoint.iot.test" },
        "activityState" => {
          "state_machine" => {
            "state" => "LEVEL2",
            "hold" => "off",
            "sticky_white_noise" => "off"
          }
        }
      )
      allow(auth).to receive(:devices).and_return([ updated_device ])

      result = described_class.new(auth: auth, devices: [ initial_device ]).change_level!(direction: "up")

      expect(mqtt_client).to have_received(:publish!).with(
        hash_including(command: "go_to_state", state: "LEVEL2", hold: "off")
      )
      expect(result[:event].resolved_state).to eq("LEVEL2")
      expect(result[:created]).to be(true)
    end
  end

  describe "#set_hold!" do
    it "publishes the current state with hold enabled" do
      updated_device = build_snoo_payload(
        "serialNumber" => "device-123",
        "awsIoT" => { "thingName" => "thing-123", "clientEndpoint" => "endpoint.iot.test" },
        "activityState" => {
          "state_machine" => {
            "state" => "LEVEL1",
            "hold" => "on"
          }
        }
      )
      allow(auth).to receive(:devices).and_return([ updated_device ])

      result = described_class.new(auth: auth, devices: [ initial_device ]).set_hold!(hold: true)

      expect(mqtt_client).to have_received(:publish!).with(
        hash_including(command: "go_to_state", state: "LEVEL1", hold: "on")
      )
      expect(result[:event].resolved_hold).to be(true)
    end
  end

  describe "#set_white_noise!" do
    it "publishes the sticky white noise command and waits for the refreshed payload" do
      updated_device = build_snoo_payload(
        "serialNumber" => "device-123",
        "awsIoT" => { "thingName" => "thing-123", "clientEndpoint" => "endpoint.iot.test" },
        "activityState" => {
          "state_machine" => {
            "state" => "LEVEL1",
            "hold" => "off",
            "sticky_white_noise" => "on"
          }
        }
      )
      allow(auth).to receive(:devices).and_return([ updated_device ])

      result = described_class.new(auth: auth, devices: [ initial_device ]).set_white_noise!(enabled: true)

      expect(mqtt_client).to have_received(:publish!).with(
        hash_including(command: "set_sticky_white_noise", state: "on", timeout_min: 15)
      )
      expect(result[:event].resolved_sticky_white_noise).to be(true)
    end
  end
end
