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

        # Try to get device status
        resp = conn.get("/hds/me/v11/devices/#{@device['serialNumber']}/state")

        if resp.success? && resp.body.present?
          payload = resp.body.to_json
          if payload != last_payload
            last_payload = payload
            process_message(payload)
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

    state_machine = data["state_machine"] || data.dig("stateMachine") || {}

    event = SnooEvent.create!(
      device_serial: @thing_name,
      event_type: data["event"] || data["eventType"] || "status",
      state: state_machine["state"] || data["state"],
      level: state_machine["level"] || state_machine["state"],
      hold: state_machine["hold"] == "on",
      left_clip: (data["left_safety_clip"].to_i == 1),
      right_clip: (data["right_safety_clip"].to_i == 1),
      sticky_white_noise: state_machine["sticky_white_noise"] == "on",
      sw_version: data["sw_version"] || data["swVersion"],
      raw_payload: raw.is_a?(String) ? raw : raw.to_json,
      event_time: data["event_time_ms"] ? Time.at(data["event_time_ms"].to_i / 1000.0) : Time.current
    )

    @on_event&.call(event)
  rescue => e
    Rails.logger.error "[SnooMQTT] Failed to process message: #{e.message}"
  end
end
