class SnooEventsChannel < ApplicationCable::Channel
  def subscribed
    stream_from "snoo_events"
  end
end
