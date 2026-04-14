require "mqtt"
require "json"
require "openssl"
require "uri"
require "net/http"
require "time"

class SnooMqttListener
  # AWS IoT MQTT over WebSocket uses ALPN protocol negotiation on port 443.
  # The ruby mqtt gem supports plain MQTT/TLS but not WebSocket transport.
  # We'll use a direct MQTT TLS connection on port 8883 with custom auth,
  # falling back to polling the Snoo API if MQTT isn't reachable.
  #
  # However, the Snoo AWS IoT endpoint requires WebSocket transport with token auth.
  # Since the ruby mqtt gem doesn't support WebSocket transport natively,
  # we'll implement a polling approach against the Snoo status endpoint
  # and also attempt direct MQTT connection.

  POLL_INTERVAL = 3 # seconds

  attr_reader :running

  def initialize(auth:, device:)
    @auth = auth
    @device = device
    @running = false
    @thread = nil
    @thing_name = device.dig("awsIoT", "thingName") || device["serialNumber"]
    @endpoint = device.dig("awsIoT", "clientEndpoint")
    @device_identifier = device["serialNumber"] || device["deviceId"] || device["id"] || @thing_name
    @state_poll_supported = true
    @last_event_signature = nil
  end

  def start(&on_event)
    return if @running

    @running = true
    @on_event = on_event

    @thread = Thread.new do
      Rails.logger.info "[SnooMQTT] Starting listener for #{@thing_name}"

      if @endpoint.present?
        mqtt_listen
      else
        poll_listen
      end
    rescue => e
      Rails.logger.error "[SnooMQTT] Listener crashed: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      @running = false
    end
  end

  def stop
    @running = false
    @mqtt_client&.disconnect rescue nil
    @thread&.kill
    @thread = nil
    Rails.logger.info "[SnooMQTT] Listener stopped"
  end

  private

  def mqtt_listen
    topic = "#{@thing_name}/state_machine/activity_state"
    control_topic = "#{@thing_name}/state_machine/control"

    loop do
      break unless @running

      @auth.refresh! if @auth.token_expired?

      begin
        Rails.logger.info "[SnooMQTT] Connecting to #{@endpoint}:443..."

        # Use the mqtt gem with TLS on port 8883
        @mqtt_client = MQTT::Client.new(
          host: @endpoint,
          port: 8883,
          ssl: true,
          client_id: "snoo_rb_#{SecureRandom.hex(4)}",
          username: "?SDK=Ruby&Version=1.0.0",
          password: @auth.id_token,
          keep_alive: 30
        )

        @mqtt_client.connect
        Rails.logger.info "[SnooMQTT] Connected! Subscribing to #{topic}"
        @mqtt_client.subscribe(topic)

        # Request current status
        @mqtt_client.publish(control_topic, JSON.generate({
          ts: (Time.now.to_f * 1000).to_i,
          command: "send_status"
        }))

        @mqtt_client.get do |t, message|
          break unless @running
          process_message(message)
        end
      rescue => e
        Rails.logger.warn "[SnooMQTT] MQTT connection failed: #{e.message}, falling back to polling"
        poll_listen
        break
      end
    end
  end

  def poll_listen
    Rails.logger.info "[SnooMQTT] Using polling mode (every #{POLL_INTERVAL}s)"
    last_payload = nil

    while @running
      begin
        @auth.refresh! if @auth.token_expired?

        conn = Faraday.new(url: SnooAuth::SNOO_API_BASE) do |f|
          f.request :json
          f.response :json
          f.headers["Authorization"] = "Bearer #{@auth.id_token}"
        end

        payload_data = fetch_poll_payload(conn)

        if payload_data.present?
          payload = payload_data.to_json
          if payload != last_payload
            last_payload = payload
            process_message(payload_data)
          end
        end
      rescue => e
      Rails.logger.warn "[SnooMQTT] Poll error: #{e.message}"
      end

      sleep POLL_INTERVAL
    end
  end

  def process_message(raw)
    data = raw.is_a?(String) ? JSON.parse(raw) : raw
    Rails.logger.info "[SnooMQTT] Event received: #{data.inspect}"

    event, created = SnooEvent.persist_payload!(data, device_serial_fallback: @thing_name, raw_payload: raw)
    signature = event.event_signature

    if signature == @last_event_signature || !created
      Rails.logger.info "[SnooMQTT] Skipping duplicate event #{signature}"
      @last_event_signature = signature
      return
    end

    @last_event_signature = signature

    @on_event&.call(event)
  rescue => e
    Rails.logger.error "[SnooMQTT] Failed to process message: #{e.message}"
  end

  def fetch_poll_payload(conn)
    payload = fetch_state_payload(conn)
    return payload if payload.present?

    devices_resp = conn.get("/hds/me/v11/devices")
    unless devices_resp.success?
      Rails.logger.warn "[SnooMQTT] Device list poll failed: HTTP #{devices_resp.status}"
      return nil
    end

    devices = unwrap_device_list(devices_resp.body)
    device_payload = devices.find { |candidate| same_device?(candidate) }

    unless device_payload
      Rails.logger.warn "[SnooMQTT] Device #{@thing_name} not found in polled device list"
      return nil
    end

    device_payload
  end

  def fetch_state_payload(conn)
    return nil if @device_identifier.blank? || !@state_poll_supported

    resp = conn.get("/hds/me/v11/devices/#{@device_identifier}/state")
    return resp.body if resp.success? && resp.body.present?

    if resp.status == 404
      @state_poll_supported = false
      Rails.logger.info "[SnooMQTT] Disabling direct state polling for #{@device_identifier} after HTTP 404"
      return nil
    end

    Rails.logger.warn "[SnooMQTT] State poll failed for #{@device_identifier}: HTTP #{resp.status}"
    nil
  end

  def unwrap_device_list(body)
    case body
    when Array
      body
    when Hash
      return [ body ] if same_device?(body)

      body.each_value do |value|
        unwrapped = unwrap_device_list(value)
        return unwrapped if unwrapped.present?
      end

      []
    else
      []
    end
  end

  def same_device?(payload)
    return false unless payload.is_a?(Hash)

    candidate_thing_name = payload.dig("awsIoT", "thingName")
    candidate_serial = payload["serialNumber"] || payload["deviceId"] || payload["id"]

    candidate_thing_name == @thing_name || candidate_serial == @device_identifier
  end
end
