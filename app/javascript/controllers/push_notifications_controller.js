import { Controller } from "@hotwired/stimulus"

// Web push for this browser: the opt-in banner, the switch on Me and the list of
// devices the server sends to (rows with data-endpoint).
// The server's list (endpointsValue) decides whether this browser counts as on.
export default class extends Controller {
  static targets = ["banner", "ask", "install", "blocked", "close", "toggle", "device"]
  static values = { endpoints: Array }

  connect() {
    this.isProcessing = false
    this.refresh()
  }

  async refresh() {
    const subscription = await this.currentSubscription()
    const registered = !!subscription && this.endpointsValue.includes(subscription.endpoint)

    if (this.hasToggleTarget) this.toggleTarget.checked = registered

    this.markThisDevice(subscription)

    if (registered) {
      this.removeBanner()
    } else {
      this.showBanner(this.promptState())
    }
  }

  // "ask" when the browser can subscribe, "install" on iPhone outside the Home Screen app
  // (Safari only offers push there), "blocked" once permission is denied, otherwise nothing
  promptState() {
    const supported = 'serviceWorker' in navigator && 'PushManager' in window && 'Notification' in window

    if (supported && Notification.permission === 'denied') return 'blocked'
    if (supported) return 'ask'
    if (this.isIOS() && !navigator.standalone) return 'install'
    return null
  }

  isIOS() {
    return /iPhone|iPad|iPod/.test(navigator.userAgent) ||
      (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1)
  }

  markThisDevice(subscription) {
    this.deviceTargets.forEach((row) => {
      const isThisDevice = !!subscription && row.dataset.endpoint === subscription.endpoint
      row.querySelector('[data-role="this-device"]')?.classList.toggle('hidden', !isThisDevice)
    })
  }

  async toggle(event) {
    if (this.isProcessing) {
      event.preventDefault()
      event.target.checked = !event.target.checked
      return
    }

    this.isProcessing = true
    const checkbox = event.target
    const wasChecked = checkbox.checked
    checkbox.disabled = true

    try {
      if (wasChecked) {
        const subscribed = await this.subscribe()
        if (!subscribed) checkbox.checked = false
      } else {
        await this.unsubscribe()
      }
      // Reload so the device list on Me matches
      Turbo.visit(window.location.href, { action: "replace" })
    } catch (error) {
      console.error('Toggle error:', error)
      checkbox.checked = !wasChecked
    } finally {
      this.isProcessing = false
      checkbox.disabled = false
    }
  }

  async currentSubscription() {
    if (!('serviceWorker' in navigator)) return null

    try {
      const registration = await navigator.serviceWorker.getRegistration()
      return registration ? await registration.pushManager.getSubscription() : null
    } catch (error) {
      console.error('Error checking subscription:', error)
      return null
    }
  }

  async subscribe() {
    if (!('serviceWorker' in navigator) || !('PushManager' in window)) {
      alert('Notifications are not supported in this browser. On iPhone, add DareWith to your Home Screen first.')
      return false
    }

    if (!window.vapidPublicKey) {
      console.error('VAPID public key not found')
      return false
    }

    try {
      const registration = await navigator.serviceWorker.register('/service-worker.js')
      await navigator.serviceWorker.ready

      const existingSub = await registration.pushManager.getSubscription()
      if (existingSub) {
        await this.sendSubscriptionToServer(existingSub)
        this.removeBanner()
        this.dispatch("subscribed", { target: window })
        return true
      }

      const permission = await Notification.requestPermission()
      if (permission !== 'granted') {
        this.removeBanner()
        return false
      }

      const sub = await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: window.vapidPublicKey
      })

      await this.sendSubscriptionToServer(sub)
      this.removeBanner()
      this.dispatch("subscribed", { target: window })
      return true
    } catch (error) {
      console.error('Subscription error:', error)
      alert('Failed to subscribe to notifications. Please try again.')
      return false
    }
  }

  async sendSubscriptionToServer(sub) {
    try {
      await fetch('/web_push_notifications', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify(sub)
      })
    } catch (error) {
      console.error('Failed to send subscription to server:', error)
    }
  }

  // Tell the server first, so it stops sending even if the browser step fails
  async unsubscribe() {
    const subscription = await this.currentSubscription()
    if (!subscription) return

    const response = await fetch('/web_push_notifications/unsubscribe', {
      method: 'DELETE',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify(subscription)
    })
    if (!response.ok) throw new Error(`Server refused to unsubscribe (${response.status})`)

    await subscription.unsubscribe()
    this.hidePromptFor(365)
  }

  // "Later" on the prompt
  dismiss() {
    this.hidePromptFor(7)
  }

  hidePromptFor(days) {
    const expires = new Date(Date.now() + days * 24 * 60 * 60 * 1000).toUTCString()
    document.cookie = `push_notification_dismissed=true; expires=${expires}; path=/`
    this.removeBanner()
  }

  showBanner(state) {
    if (!this.hasBannerTarget) return
    if (!state) return this.removeBanner()

    const stateTargets = { ask: this.askTargets, install: this.installTargets, blocked: this.blockedTargets }
    stateTargets[state].forEach((element) => element.hidden = false)
    if (state !== 'ask') this.closeTargets.forEach((element) => element.hidden = false)
    this.bannerTarget.classList.remove('hidden')
  }

  removeBanner() {
    if (this.hasBannerTarget) {
      this.bannerTarget.remove()
    }
  }
}
