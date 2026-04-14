require "rails_helper"

RSpec.describe SnooMqttCommandClient do
  describe "#publish!" do
    let(:client) do
      described_class.new(
        endpoint: "endpoint.iot.test",
        token: "id-token",
        thing_name: "thing-123"
      )
    end

    it "returns parsed JSON output from the node helper" do
      allow(Open3).to receive(:capture3).and_return([ '{"ok":true}', "", instance_double(Process::Status, success?: true) ])

      expect(client.publish!(command: "send_status")).to eq({ "ok" => true })
    end

    it "raises when the helper exits unsuccessfully" do
      allow(Open3).to receive(:capture3).and_return([ "", "boom", instance_double(Process::Status, success?: false) ])

      expect { client.publish!(command: "send_status") }.to raise_error("MQTT publish failed: boom")
    end
  end
end
