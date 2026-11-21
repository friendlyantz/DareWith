# frozen_string_literal: true

# Ready-made challenges that pre-fill the new challenge form
class ChallengeStory::Template
  # The goal and penalty are the rules; the description only says what the settings can't
  CATALOGUE = {
    push_ups: {
      emoji: "💪", chip: "Push-ups", title: "30 days of push-ups", days: 30,
      goal: {cadence: "daily", unit: "reps", target_amount: 50, target_scope: "each_period", penalty_mode: "per_miss", penalty: "a coffee"},
      description: "In as many sets as you like."
    },
    run: {
      emoji: "🏃", chip: "Run", title: "Run 3× a week", days: 28,
      goal: {cadence: "weekly", times_per_period: 3, unit: "km", target_amount: 15, target_scope: "each_period", penalty_mode: "per_miss", penalty: "$5"},
      description: "Any pace. Post a photo or your route."
    },
    hundred_km: {
      emoji: "🏅", chip: "100 km", title: "100 km in four weeks", days: 28,
      goal: {cadence: "weekly", times_per_period: 2, unit: "km", target_amount: 100, target_scope: "total", penalty_mode: "per_miss", penalty: "$5"},
      description: "Run, walk or ride: every kilometre counts."
    },
    read: {
      emoji: "📚", chip: "Reading", title: "Read 20 pages a day", days: 30,
      goal: {cadence: "daily", unit: "pages", target_amount: 20, target_scope: "each_period", penalty_mode: "per_miss", penalty: "$2"},
      description: "Any book counts. Share a line you liked."
    },
    gym: {
      emoji: "🏋️", chip: "Gym", title: "Gym 4× a week", days: 28,
      goal: {cadence: "weekly", times_per_period: 4, penalty_mode: "per_miss", penalty: "$5"},
      description: "Any workout of 30+ minutes counts. Post a photo."
    },
    meditate: {
      emoji: "🧘", chip: "Meditate", title: "Meditate for 21 days", days: 21,
      goal: {cadence: "daily", unit: "minutes", target_amount: 10, target_scope: "each_period", penalty_mode: "per_miss", penalty: "a coffee"},
      description: "With an app or without."
    },
    fasting: {
      emoji: "🍽️", chip: "Fasting", title: "Intermittent fasting, 5× a week", days: 21,
      goal: {cadence: "weekly", times_per_period: 5, unit: "hours", penalty_mode: "per_miss", penalty: "$5"},
      description: "A fast is 14 hours or more, last bite to first bite. Post your fasting app or your first meal."
    },
    vice: {
      emoji: "🚫", chip: "Vice", title: "Kick a vice for 30 days", days: 30,
      goal: {cadence: "daily", penalty_mode: "per_miss", penalty: "$10"},
      description: "Check in each day you stayed off it. Which vice is up to you."
    },
    make_bed: {
      emoji: "🛏️", chip: "Make bed", title: "Make your bed every day", days: 30,
      goal: {cadence: "daily", penalty_mode: "per_miss", penalty: "a coffee"},
      description: "Before you leave the room. Post a photo."
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

  # The short name on the template's chip, "Push-ups"
  def chip = CATALOGUE.dig(key, :chip)

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
