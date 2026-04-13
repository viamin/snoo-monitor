class SnooAuth
  COGNITO_CLIENT_ID = "6kqofhc8hm394ielqdkvli0oea"
  COGNITO_REGION = "us-east-1"
  SNOO_API_BASE = "https://api-us-east-1-prod.happiestbaby.com"

  attr_reader :access_token, :id_token, :refresh_token

  def initialize(username:, password:)
    @username = username
    @password = password
    @cognito = Aws::CognitoIdentityProvider::Client.new(
      region: COGNITO_REGION,
      credentials: Aws::Credentials.new("dummy", "dummy") # No AWS creds needed for USER_PASSWORD_AUTH
    )
  end

  def authenticate!
    resp = @cognito.initiate_auth(
      client_id: COGNITO_CLIENT_ID,
      auth_flow: "USER_PASSWORD_AUTH",
      auth_parameters: {
        "USERNAME" => @username,
        "PASSWORD" => @password
      }
    )

    @access_token = resp.authentication_result.access_token
    @id_token = resp.authentication_result.id_token
    @refresh_token = resp.authentication_result.refresh_token
    @token_expiry = Time.now + resp.authentication_result.expires_in

    Rails.logger.info "[SnooAuth] Authenticated successfully"
    self
  end

  def refresh!
    resp = @cognito.initiate_auth(
      client_id: COGNITO_CLIENT_ID,
      auth_flow: "REFRESH_TOKEN_AUTH",
      auth_parameters: {
        "REFRESH_TOKEN" => @refresh_token
      }
    )

    @access_token = resp.authentication_result.access_token
    @id_token = resp.authentication_result.id_token
    @token_expiry = Time.now + resp.authentication_result.expires_in

    Rails.logger.info "[SnooAuth] Token refreshed"
    self
  end

  def token_expired?
    @token_expiry && Time.now > (@token_expiry - 300) # 5 min buffer
  end

  def devices
    refresh! if token_expired?
    resp = api_connection.get("/hds/me/v11/devices")
    raise "Failed to fetch devices: #{resp.status}" unless resp.success?

    normalize_devices_response(resp.body)
  end

  def device_settings(device)
    refresh! if token_expired?

    snapshot = {}
    loaded_paths = []

    settings_paths(device).each do |path|
      resp = api_connection.get(path)
      next if resp.status == 404

      unless resp.success?
        Rails.logger.info "[SnooAuth] Settings probe #{path} returned HTTP #{resp.status}"
        next
      end

      next if resp.body.blank?

      snapshot[path] = resp.body
      loaded_paths << path
      Rails.logger.info "[SnooAuth] Loaded device settings from #{path}"
    end

    return nil if snapshot.empty?

    snapshot.merge("_endpoints" => loaded_paths)
  rescue => e
    Rails.logger.warn "[SnooAuth] Failed to fetch device settings: #{e.message}"
    nil
  end

  private

  def api_connection
    Faraday.new(url: SNOO_API_BASE) do |f|
      f.request :json
      f.response :json
      f.headers["Authorization"] = "Bearer #{@id_token}"
    end
  end

  def settings_paths(device)
    v10_paths + candidate_paths(device)
  end

  def v10_paths
    [
      "/us/me/v10/settings",
      "/us/me/v10/babies",
      "/us/me/v10/me",
      "/us/me/v10/devices"
    ]
  end

  def candidate_paths(device)
    ids = [
      device["serialNumber"],
      device["deviceId"],
      device["id"],
      device.dig("awsIoT", "thingName")
    ].compact.uniq

    ids.flat_map do |id|
      [
        "/hds/me/v11/devices/#{id}/settings",
        "/hds/me/v11/devices/#{id}/preferences",
        "/hds/me/v11/devices/#{id}/config",
        "/hds/me/v11/devices/#{id}/profile"
      ]
    end
  end

  def normalize_devices_response(body)
    case body
    when Array
      body
    when Hash
      return normalize_devices_response(body.values.first) if wrapper_hash?(body)

      %w[devices items data result payload].each do |key|
        next unless body.key?(key)

        return normalize_devices_response(body[key])
      end

      return [ body ] if device_payload?(body)

      raise "Unexpected devices payload shape: #{body.keys.join(", ")}"
    else
      raise "Unexpected devices payload type: #{body.class}"
    end
  end

  def device_payload?(payload)
    payload.key?("serialNumber") || payload.key?("awsIoT")
  end

  def wrapper_hash?(payload)
    return false unless payload.size == 1

    value = payload.values.first
    value.is_a?(Array) || value.is_a?(Hash)
  end
end
