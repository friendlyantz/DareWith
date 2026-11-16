# frozen_string_literal: true

class Badge < ApplicationRecord
  CATALOGUE = {
    first_check_in: {emoji: "👟", title: "First step", description: "Checked in for the first time"},
    three_day_streak: {emoji: "🔥", title: "Warming up", description: "3 days in a row in a challenge"},
    week_streak: {emoji: "⚡", title: "One week strong", description: "7 days in a row in a challenge"},
    three_week_streak: {emoji: "🏔️", title: "Habit formed", description: "21 days in a row in a challenge"},
    comeback: {emoji: "🔁", title: "Comeback", description: "Checked in again after missing a few days"},
    finisher: {emoji: "🏁", title: "Finisher", description: "Checked in on 80% of a challenge's days"},
    flawless: {emoji: "💎", title: "Flawless", description: "Checked in every day of a challenge"},
    cheerleader: {emoji: "📣", title: "Cheerleader", description: "Liked 10 check-ins from friends"},
    good_for_it: {emoji: "🤝", title: "Good for it", description: "A friend received a reward you pledged"}
  }.freeze

  # Associations
  belongs_to :user, counter_cache: true
  belongs_to :challenge_story, optional: true

  # Enums
  enum :kind, CATALOGUE.keys.map(&:to_s).index_by(&:itself)

  # Validations
  validates :kind, presence: true

  # Public methods
  def emoji = CATALOGUE.dig(kind.to_sym, :emoji)

  def title = CATALOGUE.dig(kind.to_sym, :title)

  def description = CATALOGUE.dig(kind.to_sym, :description)

  def announce
    user.notify(
      title: "#{emoji} New badge: #{title}",
      body: [description, challenge_story&.title].compact.join(" · "),
      path: Rails.application.routes.url_helpers.profile_path
    )
  end
end
