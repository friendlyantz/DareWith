# frozen_string_literal: true

# Tells Android that the DareWith app belongs to this site, so it can open its links and use its passkeys
class AndroidAssetLinksController < ApplicationController
  def show
    render json: [{
      relation: ["delegate_permission/common.handle_all_urls", "delegate_permission/common.get_login_creds"],
      target: {
        namespace: "android_app",
        package_name: Rails.configuration.android_app_package,
        sha256_cert_fingerprints: Rails.configuration.android_app_cert_fingerprints
      }
    }]
  end
end
