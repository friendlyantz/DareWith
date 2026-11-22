require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_mailbox/engine"
require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module TakeOnMe
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # The app's domain. Passkeys, emails and push all follow it
    config.app_host = "darewith.app"

    # The Android app in android/, and the SHA-256 of the keys that sign it.
    # Served in /.well-known/assetlinks.json so the app can use this site's passkeys
    config.android_app_package = "app.darewith"
    config.android_app_cert_fingerprints = [
      "A5:F1:3A:BA:34:02:02:98:BD:8E:3E:16:C1:85:78:3F:5D:16:25:3C:4B:05:CA:84:89:5C:DB:D6:72:32:BD:CC", # release
      "E5:60:07:1E:FE:7D:6B:4A:E8:08:FC:FF:43:A0:51:CC:7E:99:F2:59:73:45:2E:E2:AE:D7:2C:36:24:C0:40:A4" # debug builds from Anton's Mac
    ]

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    config.generators do |g|
      # Don't generate system test files.
      g.system_tests = nil

      g.test_framework :rspec
      g.fixture_replacement :factory_bot, dir: "spec/factories"
      g.orm :active_record, primary_key_type: :uuid
    end

    config.autoload_paths << Rails.root.join("spec/system/pages") if Rails.env.test?
  end
end
