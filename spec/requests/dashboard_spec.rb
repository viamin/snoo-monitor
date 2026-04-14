require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  def event_rows(response_body)
    Nokogiri::HTML.parse(response_body).css("tr.event-row")
  end

  def row_count(response_body)
    event_rows(response_body).count
  end

  def row_event_types(response_body)
    event_rows(response_body).map do |row|
      row.css("td")[2]&.text&.strip
    end
  end

  before do
    allow(Rails.application.credentials).to receive(:dig).with(:snoo, :username).and_return(nil)
    allow(Rails.application.credentials).to receive(:dig).with(:snoo, :password).and_return(nil)
    allow(SnooConnectionManager).to receive(:connected?).and_return(false)
    allow(SnooConnectionManager).to receive(:devices).and_return([])
    allow(SnooConnectionManager).to receive(:device_settings).and_return({})
  end

  describe "GET /" do
    it "paginates the event log to 15 events per page" do
      20.times do |index|
        create(
          :snoo_event,
          event_type: "event-#{index}",
          event_signature: "signature-#{index}",
          event_time: Time.zone.parse("2026-04-10 12:00:00") + index.minutes
        )
      end

      get root_path

      expect(response).to have_http_status(:ok)
      expect(row_count(response.body)).to eq(15)
      expect(response.body).to include("Page 1 of 2")
      expect(row_event_types(response.body)).to include("event-19")
      expect(row_event_types(response.body)).not_to include("event-4")
    end

    it "renders the second page of older events" do
      20.times do |index|
        create(
          :snoo_event,
          event_type: "event-#{index}",
          event_signature: "signature-#{index}",
          event_time: Time.zone.parse("2026-04-10 12:00:00") + index.minutes
        )
      end

      get root_path, params: { page: 2 }

      expect(response).to have_http_status(:ok)
      expect(row_count(response.body)).to eq(5)
      expect(response.body).to include("Page 2 of 2")
      expect(row_event_types(response.body)).to include("event-4")
      expect(row_event_types(response.body)).not_to include("event-19")
    end
  end

  describe "POST /snoo/connect" do
    it "passes manual credentials to the connection manager" do
      allow(SnooConnectionManager).to receive(:connect!)

      post snoo_connect_path, params: { username: "manual@example.com", password: "secret" }

      expect(SnooConnectionManager).to have_received(:connect!).with(username: "manual@example.com", password: "secret")
      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST /snoo/disconnect" do
    it "disconnects and redirects to the dashboard" do
      allow(SnooConnectionManager).to receive(:disconnect!)

      post snoo_disconnect_path

      expect(SnooConnectionManager).to have_received(:disconnect!)
      expect(response).to redirect_to(root_path)
    end
  end

  describe "control actions" do
    it "updates hold" do
      allow(SnooConnectionManager).to receive(:set_hold!)

      post snoo_hold_path, params: { hold: "true" }

      expect(SnooConnectionManager).to have_received(:set_hold!).with(hold: true)
      expect(response).to redirect_to(root_path)
    end

    it "changes level" do
      allow(SnooConnectionManager).to receive(:change_level!)

      post snoo_level_path, params: { direction: "up" }

      expect(SnooConnectionManager).to have_received(:change_level!).with(direction: "up")
      expect(response).to redirect_to(root_path)
    end

    it "updates white noise" do
      allow(SnooConnectionManager).to receive(:set_white_noise!)

      post snoo_white_noise_path, params: { enabled: "true" }

      expect(SnooConnectionManager).to have_received(:set_white_noise!).with(enabled: true)
      expect(response).to redirect_to(root_path)
    end
  end
end
