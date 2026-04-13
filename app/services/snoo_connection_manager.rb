class SnooConnectionManager
  class << self
    def instance
      @instance ||= new
    end

    delegate :connect!, :disconnect!, :connected?, :status, :devices, :device_settings, to: :instance
  end

  attr_reader :auth, :listener, :devices, :device_settings

  def initialize
    @listeners = []
    @devices = []
    @device_settings = {}
  end

  def connect!(username:, password:)
    disconnect! if connected?

    @auth = SnooAuth.new(username: username, password: password)
    @auth.authenticate!

    @devices = @auth.devices
    @device_settings = {}
    Rails.logger.info "[SnooManager] Found #{@devices.length} device(s)"

    @devices.each do |device|
      serial = device.dig("awsIoT", "thingName") || device["serialNumber"]
      Rails.logger.info "[SnooManager] Device: #{serial}"
      @device_settings[serial] = @auth.device_settings(device)

      listener = SnooMqttListener.new(auth: @auth, device: device)
      listener.start do |event|
        broadcast_event(event)
      end
      @listeners << listener
    end

    broadcast_status("connected")
  rescue => e
    Rails.logger.error "[SnooManager] Connection failed: #{e.message}"
    broadcast_status("error", e.message)
    raise
  end

  def disconnect!
    @listeners.each(&:stop)
    @listeners.clear
    @devices = []
    @device_settings = {}
    @auth = nil
    broadcast_status("disconnected")
  end

  def connected?
    @listeners.any?(&:running)
  end

  def status
    if connected?
      { state: "connected", devices: @devices.length }
    else
      { state: "disconnected", devices: 0 }
    end
  end

  private

  def broadcast_event(event)
    ActionCable.server.broadcast("snoo_events", {
      html: ApplicationController.render(
        partial: "dashboard/event_row",
        locals: { event: event }
      )
    })

    ActionCable.server.broadcast("snoo_events", {
      status_html: ApplicationController.render(
        partial: "dashboard/current_status",
        locals: { event: event }
      )
    })
  end

  def broadcast_status(state, error = nil)
    ActionCable.server.broadcast("snoo_events", {
      connection_status: state,
      error: error
    })
  end
end
