class SnooEvent < ApplicationRecord
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
    value.to_s == "on" || value.to_s == "true"
  end

  def truthy_clip?(value)
    value.to_s == "1" || value == true
  end

  def normalize_level(state)
    match = state.to_s.match(/\ALEVEL(\d+)\z/)
    match ? match[1] : state
  end
end
