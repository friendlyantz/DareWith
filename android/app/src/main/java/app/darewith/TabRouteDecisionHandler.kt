package app.darewith

import dev.hotwire.core.turbo.visit.VisitProposal
import dev.hotwire.navigation.activities.HotwireActivity
import dev.hotwire.navigation.navigator.NavigatorConfiguration
import dev.hotwire.navigation.routing.Router

// A link to another tab's page, like "Go to Today" on an empty Feed, switches to that tab
class TabRouteDecisionHandler : Router.RouteDecisionHandler {
    override val name = "tab"

    override fun matches(proposal: VisitProposal, configuration: NavigatorConfiguration): Boolean {
        val tab = Tabs.showing(proposal.location) ?: return false
        val onATab = Tabs.all.any { it.configuration == configuration }

        return onATab && tab.configuration != configuration
    }

    override fun handle(
        proposal: VisitProposal,
        configuration: NavigatorConfiguration,
        activity: HotwireActivity
    ): Router.Decision {
        (activity as MainActivity).select(Tabs.showing(proposal.location)!!)
        return Router.Decision.CANCEL
    }
}
