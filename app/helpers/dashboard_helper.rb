module DashboardHelper
  def event_gap_label(event, previous_event)
    return "-" unless event&.event_time && previous_event&.event_time

    seconds = (event.event_time - previous_event.event_time).to_i
    return "-" if seconds <= 0

    hours = seconds / 3600
    minutes = (seconds % 3600) / 60
    secs = seconds % 60

    if hours.positive?
      "#{hours}h #{minutes}m"
    elsif minutes.positive?
      "#{minutes}m #{secs}s"
    else
      "#{secs}s"
    end
  end
end
