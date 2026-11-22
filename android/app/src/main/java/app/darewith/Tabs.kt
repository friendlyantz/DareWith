package app.darewith

import androidx.core.net.toUri
import dev.hotwire.navigation.navigator.NavigatorConfiguration
import dev.hotwire.navigation.tabs.HotwireBottomTab

// Signed in, the app has these bottom tabs. Each keeps its own back stack
object Tabs {
    val all = listOf(
        tab("Today", R.drawable.ic_today, "/today", R.id.today_navigator),
        tab("Feed", R.drawable.ic_feed, "/challenge_check_ins", R.id.feed_navigator),
        tab("Alerts", R.drawable.ic_bell, "/notifications", R.id.alerts_navigator),
        tab("Me", R.drawable.ic_me, "/me", R.id.me_navigator)
    )

    val today = all.first()
    val alerts = all[2]

    // The tab whose first page is at this location, if any
    fun showing(location: String) = all.find { it.configuration.startLocation.toUri().path == location.toUri().path }

    private fun tab(title: String, icon: Int, path: String, navigatorId: Int) = HotwireBottomTab(
        title = title,
        iconResId = icon,
        configuration = NavigatorConfiguration(
            name = title.lowercase(),
            startLocation = BuildConfig.START_LOCATION + path,
            navigatorHostId = navigatorId
        )
    )
}
