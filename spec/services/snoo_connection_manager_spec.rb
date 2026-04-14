require "rails_helper"

RSpec.describe SnooConnectionManager do
  let(:manager) { described_class.new }
  let(:auth) { instance_double(SnooAuth) }
  let(:listener) { instance_double(SnooMqttListener, running: true, start: true, stop: true) }
  let(:device) { build_snoo_payload("serialNumber" => "device-123", "awsIoT" => { "thingName" => "thing-123" }) }

  before do
    allow(ActionCable.server).to receive(:broadcast)
  end

  describe "#connect!" do
    it "authenticates, loads devices and settings, and starts listeners" do
      allow(SnooAuth).to receive(:new).and_return(auth)
      allow(auth).to receive(:authenticate!).and_return(auth)
      allow(auth).to receive(:devices).and_return([ device ])
      allow(auth).to receive(:device_settings).and_return({ "sample" => "settings" })
      allow(SnooMqttListener).to receive(:new).and_return(listener)

      manager.connect!(username: "parent@example.com", password: "secret")

      expect(manager.connected?).to be(true)
      expect(manager.devices).to eq([ device ])
      expect(manager.device_settings["thing-123"]).to eq({ "sample" => "settings" })
      expect(listener).to have_received(:start)
      expect(ActionCable.server).to have_received(:broadcast).with(
        "snoo_events",
        hash_including(connection_status: "connected")
      )
    end
  end

  describe "#disconnect!" do
    it "stops listeners and clears connection state" do
      manager.instance_variable_set(:@listeners, [ listener ])
      manager.instance_variable_set(:@devices, [ device ])
      manager.instance_variable_set(:@device_settings, { "thing-123" => { "sample" => "settings" } })

      manager.disconnect!

      expect(listener).to have_received(:stop)
      expect(manager.devices).to eq([])
      expect(manager.device_settings).to eq({})
      expect(ActionCable.server).to have_received(:broadcast).with(
        "snoo_events",
        hash_including(connection_status: "disconnected")
      )
    end
  end
end
