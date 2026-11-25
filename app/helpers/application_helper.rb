module ApplicationHelper
  # The site's own bottom tabs. The Android app has native ones once someone is signed in
  def web_dock?
    !(hotwire_native_app? && current_user)
  end

  def real_browser_name
    ua = request.user_agent.to_s
    if /iPhone|iPad|iPod/.match?(ua)
      "Safari"
    elsif ua.include?("Android")
      "your browser"
    end
  end

  # Asks the phone to reopen the page outside the in-app browser; some apps ignore it.
  # iPhone can only be sent to Safari. Android picks the default browser, or our app for links it handles
  def open_in_browser_url(url)
    case real_browser_name
    when "Safari"
      "x-safari-#{url}"
    when "your browser"
      uri = URI(url)
      "intent://#{uri.host}#{uri.request_uri}#Intent;scheme=#{uri.scheme};action=android.intent.action.VIEW;category=android.intent.category.BROWSABLE;S.browser_fallback_url=#{CGI.escape(url)};end"
    end
  end

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
