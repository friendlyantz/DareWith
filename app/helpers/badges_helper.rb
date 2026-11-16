module BadgesHelper
  BADGE_TINTS = {
    "first_check_in" => "bg-info/15 ring-info/40",
    "three_day_streak" => "bg-primary/15 ring-primary/40",
    "week_streak" => "bg-warning/20 ring-warning/60",
    "three_week_streak" => "bg-success/15 ring-success/40",
    "comeback" => "bg-info/15 ring-info/40",
    "finisher" => "bg-base-content/10 ring-base-content/30",
    "flawless" => "bg-info/15 ring-info/40",
    "cheerleader" => "bg-accent/15 ring-accent/40",
    "good_for_it" => "bg-success/15 ring-success/40"
  }.freeze

  def badge_tint(badge)
    BADGE_TINTS.fetch(badge.kind)
  end
end
