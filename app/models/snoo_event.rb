require "digest"

class SnooEvent < ApplicationRecord
  CONTROLLABLE_STATES = %w[ONLINE BASELINE LEVEL1 LEVEL2 LEVEL3 LEVEL4].freeze

  def self.signature_for(attributes)
    Digest::MD5.hexdigest(signature_components(attributes).join("|"))
  end

  def self.attributes_from_payload(data, device_serial_fallback: nil, raw_payload: nil)
    activity_state = payload_activity_state(data)
    state_machine = payload_state_machine(data, activity_state)
    state = state_machine["state"] || activity_state["state"] || data["state"]

    {
      device_serial: data["serialNumber"] || device_serial_fallback,
      event_type: activity_state["event"] || activity_state["eventType"] || data["event"] || data["eventType"] || "status",
      state: state,
      level: state_machine["level"] || normalize_level_value(state),
      hold: truthy_state_value?(state_machine["hold"]),
      left_clip: truthy_clip_value?(activity_state["left_safety_clip"] || activity_state["leftSafetyClip"] || data["left_safety_clip"] || data["leftSafetyClip"]),
      right_clip: truthy_clip_value?(activity_state["right_safety_clip"] || activity_state["rightSafetyClip"] || data["right_safety_clip"] || data["rightSafetyClip"]),
      sticky_white_noise: truthy_state_value?(state_machine["sticky_white_noise"] || state_machine["stickyWhiteNoise"]),
      sw_version: activity_state["sw_version"] || activity_state["swVersion"] || data["sw_version"] || data["swVersion"] || data["firmwareVersion"],
      raw_payload: payload_json_for(raw_payload || data),
      event_time: event_time_from_payload(activity_state, data)
    }
  end

  def self.persist_payload!(data, device_serial_fallback: nil, raw_payload: nil)
    attributes = attributes_from_payload(data, device_serial_fallback: device_serial_fallback, raw_payload: raw_payload)
    signature = signature_for(attributes)
    event = create_with(attributes).create_or_find_by!(event_signature: signature)

    [ event, event.previously_new_record? ]
  end

  def self.signature_components(attributes)
    [
      attributes[:device_serial],
      attributes[:event_type],
      signature_timestamp(attributes[:event_time]),
      attributes[:state],
      attributes[:level],
      attributes[:hold],
      attributes[:left_clip],
      attributes[:right_clip],
      attributes[:sticky_white_noise],
      attributes[:sw_version],
      attributes[:raw_payload]
    ].map { |value| value.nil? ? "" : value.to_s }
  end

  def self.signature_timestamp(value)
    return if value.blank?

    value.in_time_zone("UTC").strftime("%Y-%m-%dT%H:%M:%S.%6NZ")
  end

  def self.event_time_from_payload(activity_state, data)
    timestamp_ms = activity_state["event_time_ms"] || activity_state["eventTimeMs"] || data["event_time_ms"] || data["eventTimeMs"]
    timestamp_ms ? Time.at(timestamp_ms.to_i / 1000.0) : Time.current
  end

  def self.payload_activity_state(data)
    data["activityState"] || data["activity_state"] || data
  end

  def self.payload_state_machine(data, activity_state = payload_activity_state(data))
    activity_state["state_machine"] || activity_state["stateMachine"] || data["state_machine"] || data["stateMachine"] || {}
  end

  def self.truthy_state_value?(value)
    value.to_s == "on" || value.to_s == "true"
  end

  def self.truthy_clip_value?(value)
    value.to_s == "1" || value == true
  end

  def self.normalize_level_value(state)
    match = state.to_s.match(/\ALEVEL(\d+)\z/)
    match ? match[1] : state
  end

  def self.payload_json_for(payload)
    payload.is_a?(String) ? payload : payload.to_json
  end

  def resolved_device_serial
    self[:device_serial].presence || parsed_payload["serialNumber"]
  end

  def resolved_event_type
    self[:event_type].presence || activity_state["event"] || activity_state["eventType"] || "status"
  end

  def resolved_state
    self[:state].presence || state_machine["state"] || activity_state["state"]
  end

  def resolved_level
    self[:level].presence || state_machine["level"] || normalize_level(resolved_state)
  end

  def resolved_hold
    return self[:hold] unless self[:hold].nil?

    truthy_state?(state_machine["hold"])
  end

  def resolved_left_clip
    return self[:left_clip] unless self[:left_clip].nil?

    truthy_clip?(activity_state["left_safety_clip"] || activity_state["leftSafetyClip"])
  end

  def resolved_right_clip
    return self[:right_clip] unless self[:right_clip].nil?

    truthy_clip?(activity_state["right_safety_clip"] || activity_state["rightSafetyClip"])
  end

  def resolved_sticky_white_noise
    return self[:sticky_white_noise] unless self[:sticky_white_noise].nil?

    truthy_state?(state_machine["sticky_white_noise"] || state_machine["stickyWhiteNoise"])
  end

  def resolved_sw_version
    self[:sw_version].presence || activity_state["sw_version"] || activity_state["swVersion"] || parsed_payload["firmwareVersion"]
  end

  def resolved_device_name
    parsed_payload["name"]
  end

  def resolved_system_state
    activity_state["system_state"] || activity_state["systemState"]
  end

  def resolved_audio
    state_machine["audio"]
  end

  def resolved_weaning
    state_machine["weaning"]
  end

  def resolved_up_transition
    state_machine["up_transition"] || state_machine["upTransition"]
  end

  def resolved_down_transition
    state_machine["down_transition"] || state_machine["downTransition"]
  end

  def resolved_session_active
    truthy_state?(state_machine["is_active_session"] || state_machine["isActiveSession"])
  end

  def resolved_presence_online
    parsed_payload.dig("presenceIoT", "online")
  end

  private

  def parsed_payload
    @parsed_payload ||= JSON.parse(raw_payload.presence || "{}")
  rescue JSON::ParserError
    {}
  end

  def activity_state
    @activity_state ||= parsed_payload["activityState"] || parsed_payload["activity_state"] || {}
  end

  def state_machine
    @state_machine ||= activity_state["state_machine"] || activity_state["stateMachine"] || {}
  end

  def truthy_state?(value)
    self.class.truthy_state_value?(value)
  end

  def truthy_clip?(value)
    self.class.truthy_clip_value?(value)
  end

  def normalize_level(state)
    self.class.normalize_level_value(state)
  end
end
