class SnooControl
  STATE_ORDER = SnooEvent::CONTROLLABLE_STATES.freeze
  WHITE_NOISE_TIMEOUT_MINUTES = 15
  COMMAND_WAIT_INTERVAL = 0.75
  COMMAND_WAIT_ATTEMPTS = 4

  def initialize(auth:, devices:)
    @auth = auth
    @devices = devices
  end

  def change_level!(direction:, device_serial: nil)
    offset = case direction.to_s
    when "up" then 1
    when "down" then -1
    else
      raise ArgumentError, "Unsupported level change direction: #{direction.inspect}"
    end

    device = device_for(device_serial)
    current_state = current_state_for(device)
    current_index = STATE_ORDER.index(current_state)
    raise "Current state #{current_state.inspect} cannot be adjusted from the app." unless current_index

    target_index = current_index + offset
    raise "Snoo is already at the #{offset.positive? ? 'highest' : 'lowest'} supported level." unless target_index.between?(0, STATE_ORDER.length - 1)

    target_state = STATE_ORDER[target_index]

    send_go_to_state!(
      device: device,
      target_state: target_state,
      hold: current_hold_for(device)
    )
  end

  def set_hold!(hold:, device_serial: nil)
    device = device_for(device_serial)
    current_state = current_state_for(device)
    raise "Current state #{current_state.inspect} cannot be used for hold control." unless STATE_ORDER.include?(current_state)

    send_go_to_state!(
      device: device,
      target_state: current_state,
      hold: hold
    )
  end

  def set_white_noise!(enabled:, device_serial: nil, timeout_minutes: WHITE_NOISE_TIMEOUT_MINUTES)
    device = device_for(device_serial)
    refresh_auth!

    publish_command!(
      device: device,
      command: "set_sticky_white_noise",
      state: enabled ? "on" : "off",
      timeout_min: timeout_minutes
    )

    sync_device_state!(
      device_identifier: device_identifier_for(device)
    ) do |event|
      event.resolved_sticky_white_noise == enabled
    end
  end

  private

  def send_go_to_state!(device:, target_state:, hold:)
    refresh_auth!

    publish_command!(
      device: device,
      ts: mqtt_timestamp,
      command: "go_to_state",
      state: target_state,
      hold: hold ? "on" : "off"
    )

    sync_device_state!(
      device_identifier: device_identifier_for(device)
    ) do |event|
      event.resolved_state == target_state && event.resolved_hold == hold
    end
  end

  def publish_command!(device:, **payload)
    SnooMqttCommandClient.new(
      endpoint: device.dig("awsIoT", "clientEndpoint"),
      token: @auth.id_token,
      thing_name: device.dig("awsIoT", "thingName")
    ).publish!({ ts: mqtt_timestamp }.merge(payload))
  end

  def sync_device_state!(device_identifier:)
    last_event = nil
    created = false

    COMMAND_WAIT_ATTEMPTS.times do |attempt|
      refresh_auth!
      @devices = @auth.devices

      device = device_for(device_identifier)
      last_event, created = SnooEvent.persist_payload!(
        device,
        device_serial_fallback: device.dig("awsIoT", "thingName")
      )

      if !block_given? || yield(last_event)
        return { event: last_event, created: created, devices: @devices }
      end

      sleep COMMAND_WAIT_INTERVAL if attempt < COMMAND_WAIT_ATTEMPTS - 1
    end

    { event: last_event, created: created, devices: @devices }
  end

  def refresh_auth!
    @auth.refresh! if @auth.token_expired?
  end

  def device_for(identifier = nil)
    device = if identifier.present?
      @devices.find { |candidate| device_identifiers_for(candidate).include?(identifier) }
    else
      @devices.first
    end

    raise "No Snoo device is connected." unless device

    device
  end

  def device_identifier_for(device)
    device["serialNumber"] || device.dig("awsIoT", "thingName")
  end

  def device_identifiers_for(device)
    [
      device["serialNumber"],
      device["deviceId"],
      device["id"],
      device.dig("awsIoT", "thingName")
    ].compact
  end

  def current_state_for(device)
    device.dig("activityState", "state_machine", "state") || device.dig("activityState", "state")
  end

  def current_hold_for(device)
    SnooEvent.truthy_state_value?(device.dig("activityState", "state_machine", "hold"))
  end

  def mqtt_timestamp
    (Time.now.to_f * 10_000_000).to_i
  end
end
