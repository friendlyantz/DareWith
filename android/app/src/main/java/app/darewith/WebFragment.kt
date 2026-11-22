package app.darewith

import android.os.Bundle
import android.view.View
import com.google.android.material.badge.BadgeDrawable
import com.google.android.material.badge.BadgeUtils
import com.google.android.material.badge.ExperimentalBadgeUtils
import dev.hotwire.navigation.destinations.HotwireDestinationDeepLink
import dev.hotwire.navigation.fragments.HotwireWebFragment
import org.json.JSONObject

// Every page in the app. Tells MainActivity whether someone is signed in, and has the bell once they are
@HotwireDestinationDeepLink(uri = "hotwire://fragment/web")
class WebFragment : HotwireWebFragment() {
    private val mainActivity get() = activity as? MainActivity

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        if (mainActivity?.signedIn == true) addBell()
    }

    override fun onVisitCompleted(location: String, completedOffline: Boolean) {
        super.onVisitCompleted(location, completedOffline)
        if (completedOffline) return

        navigator.session.webView.evaluateJavascript(READ_PAGE) { json ->
            val page = JSONObject(json)
            mainActivity?.pageLoaded(page.getString("location"), page.getBoolean("signedIn"), page.getInt("unreadNotifications"))
        }
    }

    @OptIn(ExperimentalBadgeUtils::class)
    private fun addBell() {
        val toolbar = toolbarForNavigation() ?: return
        toolbar.inflateMenu(R.menu.web)
        toolbar.setOnMenuItemClickListener {
            navigator.route("${BuildConfig.START_LOCATION}/notifications")
            true
        }

        val badge = BadgeDrawable.create(requireContext()).apply { maxNumber = 9 }
        BadgeUtils.attachBadgeDrawable(badge, toolbar, R.id.notifications)
        mainActivity?.unreadNotifications?.observe(viewLifecycleOwner) {
            badge.number = it
            badge.isVisible = it > 0
        }
    }

    private companion object {
        // The meta tags in app/views/layouts/application.html.erb
        const val READ_PAGE = """({
            location: location.href,
            signedIn: document.querySelector('meta[name="current-user-id"]') != null,
            unreadNotifications: Number(document.querySelector('meta[name="unread-notifications-count"]')?.content ?? 0)
        })"""
    }
}
