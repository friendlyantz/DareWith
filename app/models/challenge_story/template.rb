# frozen_string_literal: true

# Ready-made challenges that pre-fill the new challenge form
class ChallengeStory::Template
  CATALOGUE = {
    push_ups: {
      emoji: "💪", title: "30 days of push-ups", days: 30,
      goal: {cadence: "daily", unit: "reps", target_amount: 50, target_scope: "each_time"},
      description: "50 push-ups a day, in as many sets as you like. Log how many you did. Whoever misses the most days buys coffee."
    },
    run: {
      emoji: "🏃", title: "Run 3× a week", days: 28,
      goal: {cadence: "weekly", times_per_period: 3, unit: "km", target_amount: 5, target_scope: "each_time"},
      description: "Three runs a week, any pace. Log the distance and post a photo or your route. Whoever misses the most weeks buys lunch."
    },
    hundred_km: {
      emoji: "🏅", title: "100 km in four weeks", days: 28,
      goal: {cadence: "weekly", times_per_period: 2, unit: "km", target_amount: 100, target_scope: "total"},
      description: "Run, walk or ride: every kilometre counts toward 100 by the end. Get out at least twice a week."
    },
    read: {
      emoji: "📚", title: "Read 20 pages a day", days: 30,
      goal: {cadence: "daily", unit: "pages", target_amount: 20, target_scope: "each_time"},
      description: "Any book counts. Log your pages and share a line you liked."
    },
    gym: {
      emoji: "🏋️", title: "Gym 4× a week", days: 28,
      goal: {cadence: "weekly", times_per_period: 4},
      description: "Any workout of 30+ minutes counts. Post a photo. Whoever misses the most weeks buys lunch."
    },
    meditate: {
      emoji: "🧘", title: "Meditate for 21 days", days: 21,
      goal: {cadence: "daily", unit: "minutes", target_amount: 10, target_scope: "each_time"},
      description: "Ten quiet minutes a day, with an app or without. Log your minutes."
    }
  }.freeze

  def self.all = CATALOGUE.keys.map { new(it) }

  def self.find(key)
    new(key.to_sym) if CATALOGUE.key?(key.to_s.to_sym)
  end

  attr_reader :key

  def initialize(key)
    @key = key
  end

  def emoji = CATALOGUE.dig(key, :emoji)

  def title = CATALOGUE.dig(key, :title)

  def build(start: Time.zone.today)
    ChallengeStory.new(
      title:,
      description: CATALOGUE.dig(key, :description),
      start:,
      finish: start + (CATALOGUE.dig(key, :days) - 1).days,
      **CATALOGUE.dig(key, :goal)
    )
  end
end
