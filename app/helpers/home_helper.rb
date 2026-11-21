module HomeHelper
  # Where "mates" means friends. In the US it can sound like a romantic partner.
  MATES_REGIONS = %w[AU NZ GB].freeze

  # "mates" when the browser's first language is Australian, NZ or British English, otherwise "friends"
  def landing_dare_who
    first_language = request.headers["Accept-Language"].to_s.split(/[,;]/).first.to_s.strip
    region = first_language.split("-").second.to_s.upcase

    MATES_REGIONS.include?(region) ? "mates" : "friends"
  end
end
