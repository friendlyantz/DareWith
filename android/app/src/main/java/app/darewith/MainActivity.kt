package app.darewith

import android.content.Intent
import android.os.Bundle
import androidx.activity.addCallback
import androidx.activity.enableEdgeToEdge
import androidx.core.content.edit
import androidx.lifecycle.MutableLiveData
import com.google.android.material.bottomnavigation.BottomNavigationView
import dev.hotwire.navigation.activities.HotwireActivity
import dev.hotwire.navigation.navigator.NavigatorConfiguration
import dev.hotwire.navigation.tabs.HotwireBottomNavigationController
import dev.hotwire.navigation.tabs.HotwireBottomTab
import dev.hotwire.navigation.tabs.navigatorConfigurations

// Signed out, one screen with the site's own tabs. Signed in, native bottom tabs.
// Every page says whether someone is signed in; when that changes, the app starts over in the other mode.
// Invite links (https://darewith.app/c/...) open here instead of the browser
class MainActivity : HotwireActivity() {
    private val preferences by lazy { getSharedPreferences("session", MODE_PRIVATE) }
    val signedIn by lazy { preferences.getBoolean(SIGNED_IN, false) }

    // The Alerts tab's count, from the last page loaded
    val unreadNotifications = MutableLiveData(0)

    private lateinit var bottomNavigation: HotwireBottomNavigationController
    private var openOnStart: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)

        if (savedInstanceState == null) openOnStart = intent.getStringExtra(OPEN_ON_START) ?: intent.linkedPage()

        if (signedIn) showTabs() else setContentView(R.layout.activity_main)
    }

    override fun navigatorConfigurations() =
        if (signedIn) Tabs.all.navigatorConfigurations else listOf(signedOut)

    // An invite link tapped while the app is already open
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        intent.linkedPage()?.let { delegate.currentNavigator?.route(it) }
    }

    fun pageLoaded(location: String, signedIn: Boolean, unreadNotifications: Int) {
        this.unreadNotifications.value = unreadNotifications
        if (isFinishing) return

        if (signedIn != this.signedIn) {
            preferences.edit { putBoolean(SIGNED_IN, signedIn) }
            return startOver(openOnStart = openOnStart ?: location.takeIf { signedIn && Tabs.showing(it) == null })
        }

        // An invite or "make your first challenge" opens over the first page once it has loaded, so back goes there
        openOnStart?.let { delegate.currentNavigator?.route(it) }
        openOnStart = null
    }

    fun select(tab: HotwireBottomTab) = bottomNavigation.selectTab(Tabs.all.indexOf(tab))

    private fun showTabs() {
        setContentView(R.layout.activity_tabs)
        bottomNavigation = HotwireBottomNavigationController(this, findViewById(R.id.bottom_navigation), lazyLoadTabs = true)
        bottomNavigation.load(Tabs.all)

        val alertsBadge = findViewById<BottomNavigationView>(R.id.bottom_navigation).getOrCreateBadge(Tabs.all.indexOf(Tabs.alerts))
        alertsBadge.maxNumber = 9
        unreadNotifications.observe(this) {
            alertsBadge.number = it
            alertsBadge.isVisible = it > 0
        }

        // Back on the first page of another tab goes to Today first, like other Android apps
        onBackPressedDispatcher.addCallback(this) {
            val navigator = delegate.currentNavigator
            when {
                navigator?.isAtStartDestination() == false -> navigator.pop()
                bottomNavigation.currentTab != Tabs.today -> select(Tabs.today)
                else -> {
                    isEnabled = false
                    onBackPressedDispatcher.onBackPressed()
                    isEnabled = true
                }
            }
        }
    }

    // A fresh start, so no tab shows the previous person's pages
    // (clearing the task, since there is only ever one of this screen)
    private fun startOver(openOnStart: String?) {
        startActivity(
            Intent(this, MainActivity::class.java)
                .putExtra(OPEN_ON_START, openOnStart)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
        )
    }

    // The same page on this build's site (debug builds use localhost)
    private fun Intent.linkedPage() = data?.takeIf { action == Intent.ACTION_VIEW }?.path?.let { BuildConfig.START_LOCATION + it }

    private companion object {
        const val SIGNED_IN = "signed_in"
        const val OPEN_ON_START = "open_on_start"

        val signedOut = NavigatorConfiguration(
            name = "signed_out",
            startLocation = BuildConfig.START_LOCATION,
            navigatorHostId = R.id.main_navigator
        )
    }
}
