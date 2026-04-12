class DashboardController < ApplicationController
  def index
    @events = SnooEvent.order(event_time: :desc).limit(100)
    @latest = @events.first
    @connected = SnooConnectionManager.connected?
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
