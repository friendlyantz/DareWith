package app.darewith

import android.os.Bundle
import android.view.View
import androidx.appcompat.widget.Toolbar
import androidx.core.graphics.Insets
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.isVisible
import androidx.core.view.updateLayoutParams
import androidx.core.view.updatePadding
import dev.hotwire.navigation.destinations.HotwireDestinationDeepLink
import dev.hotwire.navigation.fragments.HotwireWebFragment
import org.json.JSONObject

// Every page in the app. Tells MainActivity whether someone is signed in and how many alerts are unread.
// No toolbar: the page fills the screen and scrolls under the status bar; forms that slide up get a
// close button floating over it (layout/hotwire_fragment_web.xml)
@HotwireDestinationDeepLink(uri = "hotwire://fragment/web")
class WebFragment : HotwireWebFragment() {
    private val mainActivity get() = activity as? MainActivity

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        keepBelowStatusBar(view)

        if (isModal) {
            showClose(view)
        } else if (mainActivity?.signedIn == true) {
            leaveGestureBarToTabs(view)
        }
    }

    // No title or back arrow: the page has its own heading, and Android has the back gesture
    override fun toolbarForNavigation(): Toolbar? = null

    override fun onVisitCompleted(location: String, completedOffline: Boolean) {
        super.onVisitCompleted(location, completedOffline)
        if (completedOffline) return

        navigator.session.webView.evaluateJavascript(READ_PAGE) { json ->
            val page = JSONObject(json)
            mainActivity?.pageLoaded(page.getString("location"), page.getBoolean("signedIn"), page.getInt("unreadNotifications"))
        }
    }

    // The tabs sit below the page and cover the gesture bar, so the page (its env(safe-area-inset-bottom))
    // shouldn't leave room for it as well. Forms that slide up cover the tabs and keep the room
    private fun leaveGestureBarToTabs(view: View) {
        ViewCompat.setOnApplyWindowInsetsListener(view.findViewById(dev.hotwire.navigation.R.id.hotwire_view)) { _, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.navigationBars())
            WindowInsetsCompat.Builder(insets)
                .setInsets(WindowInsetsCompat.Type.navigationBars(), Insets.of(bars.left, bars.top, bars.right, 0))
                .build()
        }
    }

    // The close button sits just below the status bar, and the page fades out under it
    private fun keepBelowStatusBar(view: View) {
        val buttons = view.findViewById<View>(R.id.floating_buttons)
        val fade = view.findViewById<View>(R.id.status_bar_fade)

        ViewCompat.setOnApplyWindowInsetsListener(view) { _, insets ->
            val statusBar = insets.getInsets(WindowInsetsCompat.Type.statusBars()).top
            buttons.updatePadding(top = statusBar + buttons.paddingBottom)
            fade.updateLayoutParams { height = statusBar * 2 }
            insets
        }
    }

    private fun showClose(view: View) {
        view.findViewById<View>(R.id.close).apply {
            isVisible = true
            setOnClickListener { navigator.pop() }
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
