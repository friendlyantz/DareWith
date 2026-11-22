// The Android app's WebView has no navigator.share, so in the app the share buttons ask the app
// to open Android's share sheet instead (ShareComponent in android/). Returns false outside the app.
import "@hotwired/hotwire-native-bridge"

export function shareInApp({ title, text, image, fileName }) {
  const bridge = window.HotwireNative.web
  if (!bridge.supportsComponent("share")) return false

  bridge.send({
    component: "share",
    event: "share",
    data: { title, text, image, fileName, metadata: { url: window.location.href } }
  })
  return true
}

export function dataUrl(blob) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onload = () => resolve(reader.result)
    reader.onerror = () => reject(reader.error)
    reader.readAsDataURL(blob)
  })
}
