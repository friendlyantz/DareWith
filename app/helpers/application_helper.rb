module ApplicationHelper
  def short_time_ago(time)
    seconds = (Time.current - time).to_i
    return "just now" if seconds < 1.minute

    if seconds < 1.hour
      "#{seconds / 1.minute}m ago"
    elsif seconds < 1.day
      "#{seconds / 1.hour}h ago"
    else
      "#{seconds / 1.day}d ago"
    end
  end
end
