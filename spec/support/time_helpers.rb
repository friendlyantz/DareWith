require "active_support/testing/time_helpers"

RSpec.configure do |config|
  config.include ActiveSupport::Testing::TimeHelpers
  # Rails only resets the clock in Minitest's after_teardown, which RSpec never calls
  config.after { travel_back } # standard:disable Rails/RedundantTravelBack
end
