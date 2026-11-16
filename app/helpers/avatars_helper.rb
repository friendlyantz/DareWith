module AvatarsHelper
  AVATAR_TINTS = %w[
    bg-orange-200 bg-sky-200 bg-emerald-200 bg-violet-200
    bg-amber-200 bg-rose-200 bg-teal-200 bg-indigo-200
  ].freeze

  def avatar_tint(name)
    AVATAR_TINTS[Zlib.crc32(name) % AVATAR_TINTS.size]
  end

  def avatar_initials(name)
    parts = name.split(/[\s_.-]+/).compact_blank
    letters = (parts.size > 1) ? parts.first(2).map(&:first) : [name.first, name.last]
    letters.join.upcase
  end
end
