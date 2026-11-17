# frozen_string_literal: true

# Precompile assets before running tests to avoid timeouts.
# Do not precompile if webpack-dev-server is running (NOTE: MUST be launched with RAILS_ENV=test)
RSpec.configure do |config|
  config.before(:suite) do
    examples = RSpec.world.filtered_examples.values.flatten
    has_no_system_tests = examples.none? { |example| example.metadata[:type] == :system }

    if has_no_system_tests
      $stdout.puts "\n🚀️️  No system test selected. Skip assets compilation.\n"
      next
    end

    $stdout.puts "\n🐢  Precompiling assets.\n"
    original_stdout = $stdout.clone

    start = Time.current
    begin
      $stdout.reopen(File.new(File::NULL, "w"))

      require "rake"
      Rails.application.load_tasks
      Rake::Task["assets:precompile"].invoke
    ensure
      $stdout.reopen(original_stdout)
      $stdout.puts "Finished in #{(Time.current - start).round(2)} seconds"
    end
  end

  # Left behind, the compiled assets would be served in development instead of the live files
  config.after(:suite) do
    FileUtils.rm_rf(Rails.public_path.join("assets"))
  end
end
