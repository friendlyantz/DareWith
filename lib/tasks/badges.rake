namespace :badges do
  desc "Award badges for past activity without notifying anyone"
  task backfill: :environment do
    User.find_each { BadgeAwardJob.perform_now(it, announce: false) }
  end
end
