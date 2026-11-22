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

// Chrome offers to install the app once per page load, often before any controller
// connects, so keep the offer for the install-app controller to use later
window.addEventListener("beforeinstallprompt", (event) => {
  window.installAppPrompt = event
  window.dispatchEvent(new CustomEvent("install-app:changed"))
})
window.addEventListener("appinstalled", () => {
  rememberAppInstalled()
  window.installAppPrompt = null
  window.dispatchEvent(new CustomEvent("install-app:changed"))
})

// Some browsers (Brave) keep offering to install the app after it's on the Home Screen,
// so the browser tab learns it's installed once the app has been opened or added
function rememberAppInstalled() {
  document.cookie = "app_installed=true; path=/; max-age=31536000; samesite=lax"
}
if (window.matchMedia("(display-mode: standalone)").matches) rememberAppInstalled()

// Detect Telegram WebView and set a cookie
document.addEventListener('DOMContentLoaded', () => {
  const isTelegramAndroid = navigator.userAgent.includes('Android') && typeof TelegramWebview !== 'undefined';
  const isTelegramIOS = navigator.userAgent.includes('iPhone') && typeof TelegramWebviewProxy !== 'undefined';
  if (isTelegramAndroid || isTelegramIOS) {
    document.cookie = 'telegram_webview=true; path=/';
  }
});

Rails.start();
