require "open3"

class SnooMqttCommandClient
  SCRIPT_PATH = Rails.root.join("script", "snoo_mqtt_command.mjs")

  def initialize(endpoint:, token:, thing_name:)
    @endpoint = endpoint
    @token = token
    @thing_name = thing_name
  end

  def publish!(payload)
    stdout, stderr, status = Open3.capture3(
      { "SNOO_ID_TOKEN" => @token },
      "node",
      SCRIPT_PATH.to_s,
      @endpoint,
      @thing_name,
      payload.to_json,
      chdir: Rails.root.to_s
    )

    raise "MQTT publish failed: #{stderr.presence || stdout.presence || 'unknown error'}" unless status.success?

    JSON.parse(stdout.presence || "{}")
  rescue JSON::ParserError
    {}
  end
end
