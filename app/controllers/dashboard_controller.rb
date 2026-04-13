class DashboardController < ApplicationController
  def index
    @events = SnooEvent.order(event_time: :desc).limit(100)
    @latest = @events.first
    @connected = SnooConnectionManager.connected?
    @credentials_configured = snoo_credentials.values.all?(&:present?)
    primary_device = SnooConnectionManager.devices.first
    primary_serial = primary_device&.dig("awsIoT", "thingName") || primary_device&.[]("serialNumber")
    @device_settings = primary_serial && SnooConnectionManager.device_settings[primary_serial]
  end

  def connect
    credentials = snoo_credentials

    SnooConnectionManager.connect!(
      username: credentials[:username].presence || params[:username],
      password: credentials[:password].presence || params[:password]
    )

    redirect_to root_path, notice: "Connected to Snoo!"
  rescue => e
    redirect_to root_path, alert: "Connection failed: #{e.message}"
  end

  def disconnect
    SnooConnectionManager.disconnect!
    redirect_to root_path, notice: "Disconnected from Snoo."
  end

  private

  def snoo_credentials
    {
      username: Rails.application.credentials.dig(:snoo, :username),
      password: Rails.application.credentials.dig(:snoo, :password)
    }
  end
end
