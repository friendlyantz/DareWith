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
        # The dock's tabs (and the signed-out home) replace the screen instead of stacking up
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
