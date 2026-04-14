class DashboardController < ApplicationController
  def index
    @events = SnooEvent.order(event_time: :desc).limit(100)
    @latest = @events.first
    @connected = SnooConnectionManager.connected?
    @credentials_configured = snoo_credentials.values.all?(&:present?)
    @primary_device = SnooConnectionManager.devices.first
    primary_key = @primary_device&.dig("awsIoT", "thingName") || @primary_device&.[]("serialNumber")
    @device_settings = primary_key && SnooConnectionManager.device_settings[primary_key]
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

  def update_hold
    hold = ActiveModel::Type::Boolean.new.cast(params[:hold])
    SnooConnectionManager.set_hold!(hold: hold)

    redirect_to root_path, notice: "Hold turned #{hold ? 'on' : 'off'}."
  rescue => e
    redirect_to root_path, alert: "Hold update failed: #{e.message}"
  end

  def change_level
    direction = params[:direction].to_s
    SnooConnectionManager.change_level!(direction: direction)

    redirect_to root_path, notice: "Sent Snoo level #{direction} command."
  rescue => e
    redirect_to root_path, alert: "Level change failed: #{e.message}"
  end

  def update_white_noise
    enabled = ActiveModel::Type::Boolean.new.cast(params[:enabled])
    SnooConnectionManager.set_white_noise!(enabled: enabled)

    redirect_to root_path, notice: "White noise turned #{enabled ? 'on' : 'off'}."
  rescue => e
    redirect_to root_path, alert: "White noise update failed: #{e.message}"
  end

  private

  def snoo_credentials
    {
      username: Rails.application.credentials.dig(:snoo, :username),
      password: Rails.application.credentials.dig(:snoo, :password)
    }
  end
end
