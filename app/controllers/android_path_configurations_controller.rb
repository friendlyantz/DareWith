# frozen_string_literal: true

# How the Android app presents each page. The app downloads this on launch and keeps
# a bundled copy (android/app/src/main/assets/json/path-configuration.json) for its first start.
# Rules cascade: every matching rule's properties apply, later ones win.
class AndroidPathConfigurationsController < ApplicationController
  def show
    render json: {
      settings: {},
      rules: [
        {
          patterns: [".*"],
          properties: {context: "default", pull_to_refresh_enabled: true}
        },
        # Going back to a tab's first page (or the signed-out home) starts that tab over instead of stacking up.
        # A link to another tab's first page switches tabs instead (TabRouteDecisionHandler in the app)
        {
          patterns: ["^/(\\?|$)", "^/today(\\?|$)", "^/challenge_check_ins(\\?|$)", "^/me(\\?|$)"],
          properties: {presentation: "replace_root"}
        },
        # Pulling down on a form would throw away what was typed
        {
          patterns: ["/new(\\?|$)", "/edit(\\?|$)", "^/webauthn/", "^/email/", "^/device_sign_in"],
          properties: {pull_to_refresh_enabled: false}
        }
      ]
    }
  end
end
