class BadgeAwardJob < ApplicationJob
  def perform(user, announce: true)
    badges = Badge::Awarder.new(user).award
    badges.each(&:announce) if announce
  end
end
