package app.darewith

import android.app.Application
import dev.hotwire.core.config.Hotwire
import dev.hotwire.core.turbo.config.PathConfiguration

class DareWithApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        // Passkeys for darewith.app. The site allows this app in /.well-known/assetlinks.json.
        // Safe because the WebView only loads our own site: other links open in the browser.
        Hotwire.config.webAuthenticationEnabled = true

        // Lets chrome://inspect on the Mac debug the page in debug builds
        Hotwire.config.webViewDebuggingEnabled = BuildConfig.DEBUG

        // How each page is presented (tabs, pull-to-refresh). The site's copy wins once downloaded
        Hotwire.loadPathConfiguration(
            context = this,
            location = PathConfiguration.Location(
                assetFilePath = "json/path-configuration.json",
                remoteFileUrl = "${BuildConfig.START_LOCATION}/configurations/android_v1.json"
            )
        )
    }
}
