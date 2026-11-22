package app.darewith

import android.app.Application
import dev.hotwire.core.config.Hotwire
import dev.hotwire.core.turbo.config.PathConfiguration
import dev.hotwire.navigation.config.defaultFragmentDestination
import dev.hotwire.navigation.config.registerFragmentDestinations
import dev.hotwire.navigation.config.registerRouteDecisionHandlers
import dev.hotwire.navigation.fragments.HotwireWebBottomSheetFragment
import dev.hotwire.navigation.routing.AppNavigationRouteDecisionHandler
import dev.hotwire.navigation.routing.BrowserTabRouteDecisionHandler
import dev.hotwire.navigation.routing.SystemNavigationRouteDecisionHandler

class DareWithApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        // Passkeys for darewith.app. The site allows this app in /.well-known/assetlinks.json.
        // Safe because the WebView only loads our own site: other links open in the browser.
        Hotwire.config.webAuthenticationEnabled = true

        // Lets chrome://inspect on the Mac debug the page in debug builds
        Hotwire.config.webViewDebuggingEnabled = BuildConfig.DEBUG

        // Every page opens in our WebFragment (signed-in check, alerts count)
        Hotwire.defaultFragmentDestination = WebFragment::class
        Hotwire.registerFragmentDestinations(WebFragment::class, HotwireWebBottomSheetFragment::class)

        // Links to another tab's page switch tabs; the rest is Hotwire's default routing
        Hotwire.registerRouteDecisionHandlers(
            TabRouteDecisionHandler(),
            AppNavigationRouteDecisionHandler(),
            BrowserTabRouteDecisionHandler(),
            SystemNavigationRouteDecisionHandler()
        )

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
