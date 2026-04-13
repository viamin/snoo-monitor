class DashboardController < ApplicationController
  def index
    @events = SnooEvent.order(event_time: :desc).limit(100)
    @latest = @events.first
    @connected = SnooConnectionManager.connected?
    primary_device = SnooConnectionManager.devices.first
    primary_serial = primary_device&.dig("awsIoT", "thingName") || primary_device&.[]("serialNumber")
    @device_settings = primary_serial && SnooConnectionManager.device_settings[primary_serial]
  end

  def connect
    SnooConnectionManager.connect!(
      username: params[:username],
      password: params[:password]
    )

    redirect_to root_path, notice: "Connected to Snoo!"
  rescue => e
    redirect_to root_path, alert: "Connection failed: #{e.message}"
  end

  def disconnect
    SnooConnectionManager.disconnect!
    redirect_to root_path, notice: "Disconnected from Snoo."
  end
end
