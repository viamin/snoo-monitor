require "rails_helper"
require "ostruct"

RSpec.describe SnooAuth do
  let(:cognito_client) { instance_double(Aws::CognitoIdentityProvider::Client) }
  let(:auth) { described_class.new(username: "parent@example.com", password: "secret") }

  before do
    allow(Aws::CognitoIdentityProvider::Client).to receive(:new).and_return(cognito_client)
  end

  describe "#authenticate!" do
    it "stores tokens returned by Cognito" do
      response = OpenStruct.new(
        authentication_result: OpenStruct.new(
          access_token: "access-token",
          id_token: "id-token",
          refresh_token: "refresh-token",
          expires_in: 3600
        )
      )
      allow(cognito_client).to receive(:initiate_auth).and_return(response)

      auth.authenticate!

      expect(auth.access_token).to eq("access-token")
      expect(auth.id_token).to eq("id-token")
      expect(auth.refresh_token).to eq("refresh-token")
      expect(auth).not_to be_token_expired
    end
  end

  describe "#devices" do
    it "fetches devices from the Snoo API and normalizes wrapper payloads" do
      auth.instance_variable_set(:@id_token, "id-token")
      auth.instance_variable_set(:@token_expiry, 1.hour.from_now)

      stub_request(:get, "#{described_class::SNOO_API_BASE}/hds/me/v11/devices")
        .with(headers: { "Authorization" => "Bearer id-token" })
        .to_return(
          status: 200,
          body: { "devices" => [ { "serialNumber" => "12345" } ] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      expect(auth.devices).to eq([ { "serialNumber" => "12345" } ])
    end
  end

  describe "#device_settings" do
    it "collects successful settings endpoints and ignores 404s" do
      auth.instance_variable_set(:@id_token, "id-token")
      auth.instance_variable_set(:@token_expiry, 1.hour.from_now)

      device = { "serialNumber" => "12345", "awsIoT" => { "thingName" => "thing-12345" } }

      stub_request(:any, /api-us-east-1-prod\.happiestbaby\.com/).to_return(
        status: 404,
        body: { message: "Not Found" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

      stub_request(:get, "#{described_class::SNOO_API_BASE}/us/me/v10/settings")
        .to_return(
          status: 200,
          body: { daytimeStart: 7 }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
      stub_request(:get, "#{described_class::SNOO_API_BASE}/us/me/v10/babies")
        .to_return(
          status: 200,
          body: [ { settings: { responsivenessLevel: "lvl-2" } } ].to_json,
          headers: { "Content-Type" => "application/json" }
        )

      snapshot = auth.device_settings(device)

      expect(snapshot).to include(
        "/us/me/v10/settings" => { "daytimeStart" => 7 },
        "/us/me/v10/babies" => [ { "settings" => { "responsivenessLevel" => "lvl-2" } } ]
      )
      expect(snapshot["_endpoints"]).to include("/us/me/v10/settings", "/us/me/v10/babies")
    end
  end
end
