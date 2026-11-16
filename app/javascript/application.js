// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "credential"
import "messenger"

import Rails from "@rails/ujs";

// Remember the browser's time zone so "today" matches the user's own day
try {
  const timeZone = Intl.DateTimeFormat().resolvedOptions().timeZone
  if (timeZone) document.cookie = `time_zone=${encodeURIComponent(timeZone)}; path=/; max-age=31536000; samesite=lax`
} catch (error) {
  console.warn("Could not detect time zone", error)
}

// Detect Telegram WebView and set a cookie
document.addEventListener('DOMContentLoaded', () => {
  const isTelegramAndroid = navigator.userAgent.includes('Android') && typeof TelegramWebview !== 'undefined';
  const isTelegramIOS = navigator.userAgent.includes('iPhone') && typeof TelegramWebviewProxy !== 'undefined';
  if (isTelegramAndroid || isTelegramIOS) {
    document.cookie = 'telegram_webview=true; path=/';
  }
});

Rails.start();
