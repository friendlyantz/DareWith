package app.darewith

import android.app.Application
import dev.hotwire.core.config.Hotwire

class DareWithApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        // Passkeys for darewith.app. The site allows this app in /.well-known/assetlinks.json.
        // Safe because the WebView only loads our own site: other links open in the browser.
        Hotwire.config.webAuthenticationEnabled = true

        // Lets chrome://inspect on the Mac debug the page in debug builds
        Hotwire.config.webViewDebuggingEnabled = BuildConfig.DEBUG
    }
}
