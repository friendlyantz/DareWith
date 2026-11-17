# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

require "open-uri"

print_counts = lambda do
  puts "  Users: #{User.count}"
  puts "  Challenge Stories: #{ChallengeStory.count}"
  puts "  Challenge Participants: #{ChallengeParticipant.count}"
  puts "  Check-ins: #{ChallengeCheckIn.count}"
  puts "  Check-in Likes: #{ChallengeCheckInLike.count}"
  puts "  Check-in Replies: #{ChallengeCheckInReply.count}"
  puts "  Rewards: #{ChallengeReward.count}"
  puts "  Story Likes: #{ChallengeStoryLike.count}"
  puts "  Badges: #{Badge.count}"
end

puts "🌱 Seeding database..."
puts "\n📊 Current State:"
print_counts.call

# Clean up existing demo data
puts "🧹 Cleaning up existing demo data..."

demo_users = {
  alice: {id: "00000000-0001-4000-8000-000000000000", username: "AliceWonderland", payment_details: "paypal.me/alicewonderland"},
  bob: {id: "00000000-0002-4000-8000-000000000000", username: "BobBuilder"},
  charlie: {id: "00000000-0003-4000-8000-000000000000", username: "CharlieChocolate"},
  dora: {id: "00000000-0004-4000-8000-000000000000", username: "DoraExplorer", payment_details: "PayID dora@example.com"}
}
demo_user_ids = demo_users.values.pluck(:id)

demo_challenge_story_ids = ChallengeParticipant
  .where(user_id: demo_user_ids)
  .pluck(:challenge_story_id)
  .uniq

# Purge photos now rather than in a background job, which may not run before seeding exits and would leave them on Cloudinary
if Cloudinary.config.api_key.present?
  ChallengeCheckIn.where(challenge_story_id: demo_challenge_story_ids).joins(:photo_attachment).find_each { it.photo.purge }
end

# Destroy individually to trigger callbacks and dependent destroys
ChallengeStory.where(id: demo_challenge_story_ids).find_each(&:destroy)
User.where(id: demo_user_ids).find_each(&:destroy)

puts "✅ Cleanup complete"

# Create demo users with consistent UUIDs
users = demo_users.transform_values do |attrs|
  user = User.create!(attrs.except(:id))
  user.update_column(:id, attrs[:id])
  user
end

puts "✅ there are now #{User.count} users"

# Free Unsplash photos (unsplash.com/license), fetched from their CDN at seed time
demo_photos = {
  deadlift: "1517836357463-d25dfeac3438",
  dumbbell_rack: "1534438327276-14e5300c3a48",
  bicep_curl: "1581009146145-b5ef050c2e1e",
  sit_ups: "1571019613454-1cb2f99b2d8b",
  book_stack: "1512820790803-83ca734da794",
  book_spines: "1495446815901-a7297e633e8d",
  library: "1481627834876-b7833e8f5570",
  sunset_meditation: "1506126613408-eca07ce68773",
  sunrise_arms: "1499209974431-9dddcece7f88",
  beach_yoga: "1544367567-0f2fcb009e0b"
}

attach_demo_photo = lambda do |check_in, photo|
  return if Cloudinary.config.api_key.blank?

  url = "https://images.unsplash.com/photo-#{demo_photos.fetch(photo)}?w=1200&q=75&fm=jpg"
  check_in.photo.attach(io: URI.parse(url).open, filename: "#{photo}.jpg", content_type: "image/jpeg")
rescue OpenURI::HTTPError, SocketError, SystemCallError => err
  puts "  ⚠️  Skipped photo #{photo}: #{err.message}"
end

# Nothing is dated in the future: today's check-ins and replies land just before now, in order
not_after_now = ->(time, minutes_early) { [time, Time.current - minutes_early.minutes].min }

# Challenges are laid out by day of the challenge (day 1 is the start date), so check-ins always fall inside its dates.
# Offsets are days from today.
challenge_data = {
  "00000000-0000-4000-8000-000000000001" => {
    title: "30-Day Gym Challenge(DEMO)",
    description: "Hit the gym every day for 30 days, 45 minutes a session. Build strength, endurance, and healthy habits together. 💪",
    start_offset: -6,
    days: 30,
    unit: :minutes,
    target_amount: 45,
    target_scope: :each_time,
    participants: %i[alice bob charlie],
    check_ins: {
      alice: [
        {day: 1, message: "Day 1: Gym session complete! 💪", amount: 45},
        {day: 2, message: "Day 2: Feeling stronger already! 🏋️‍♀️", amount: 50},
        {day: 3, message: "Day 3: Leg day was tough but worth it! 🦵", amount: 45},
        {day: 4, message: "Upper body and a long stretch 🧘‍♀️", amount: 55},
        {day: 5, message: "Short one, but it counts ⏱️", amount: 30},
        {day: 6, message: "Rowing intervals, lungs on fire 🚣‍♀️", amount: 45},
        {day: 7, message: "One week in a row! 🔥", amount: 60, photo: :dumbbell_rack,
         replies: [[:bob, "Look at you go! See you there tomorrow 🙌"], [:alice, "6am, don't be late 😤"]]}
      ],
      bob: [
        {day: 1, message: "First workout! 🚀", amount: 40},
        {day: 2, message: "Morning grind 🌅", amount: 35},
        {day: 3, message: "Bench press 💪", amount: 45},
        {day: 5, message: "PR today! 🎯", amount: 45, photo: :bicep_curl},
        {day: 6, message: "Leg day! 🏋️‍♂️", amount: 50, photo: :deadlift,
         replies: [[:charlie, "That form though 👀"], [:bob, "Years of practice lifting bricks 🧱"]]},
        {day: 7, message: "Quick cardio before work 🏃‍♂️", amount: 25, hour: 7},
        {day: 7, message: "Back for an evening lift, couldn't help it 😅", amount: 40, hour: 19}
      ],
      charlie: [
        {day: 1, message: "Day 1: Finally made it! 😅", amount: 30},
        {day: 4, message: "Missed a couple of days, back at it 🔁", amount: 45},
        {day: 5, message: "another day Squats and lunges 🦵", amount: 45},
        {day: 6, message: "Strong week! 💪", amount: 50, photo: :sit_ups,
         replies: [[:alice, "Proud of you! What a comeback 💛"]]}
      ]
    },
    rewards: [
      {giver: :bob, receiver: :alice, description: "I'll buy you a protein smoothie if you don't miss a single day! 🥤"},
      {giver: :alice, receiver: :charlie, description: "Complete 20 days and I'll get you those gym gloves you wanted! 🧤"}
    ]
  },
  "00000000-0000-4000-8000-000000000002" => {
    title: "Read Books Challenge(DEMO)",
    description: "Read at least twice a week for three weeks and log your pages. 300 pages each by the end. Share insights and recommendations! 📚",
    start_offset: -25,
    days: 21,
    completed: true,
    cadence: :weekly,
    times_per_period: 2,
    unit: :pages,
    target_amount: 300,
    target_scope: :total,
    participants: %i[alice bob dora],
    check_ins: {
      alice: [
        {day: 2, message: "Book 1: 'Atomic Habits' 📖", amount: 40},
        {day: 5, message: "Still going strong habits!", amount: 45},
        {day: 8, message: "Started 'Sapiens' - fascinating read! 🧠", amount: 50},
        {day: 11, message: "Halfway through 'Sapiens' 🤯", amount: 60},
        {day: 16, message: "Finished 'Sapiens', what a ride", amount: 55},
        {day: 19, message: "Book 3: 'The Midnight Library' 🌙", amount: 70, photo: :book_stack,
         replies: [[:dora, "That stack is goals 😍"]]}
      ],
      dora: [
        {day: 3, message: "'Where the Crawdads Sing' 🦋", amount: 35},
        {day: 6, message: "Crawdads, part two. Can't stop 🌾", amount: 30},
        {day: 10, message: "Rainy day, reading in bed ☔", amount: 40},
        {day: 17, message: "'The Silent Patient' 😱", amount: 50, photo: :book_spines,
         replies: [[:alice, "Loved that one! Tell me when you reach the twist"], [:dora, "No spoilers!! 🙉"]]}
      ],
      bob: [
        {day: 4, message: "Started '1984'", amount: 25},
        {day: 12, message: "'The Alchemist' 🌟", amount: 40, photo: :library}
      ]
    },
    rewards: [
      {giver: :alice, receiver: :dora, description: "Hit 300 pages and I'll buy you that Kindle! 📱", fulfilled: true},
      {giver: :dora, receiver: :alice, description: "I'll recommend my top 5 books! 📚", fulfilled: true}
    ]
  },
  "00000000-0000-4000-8000-000000000004" => {
    previous: "00000000-0000-4000-8000-000000000002",
    title: "Read Books Challenge(DEMO)",
    description: "Read at least twice a week for three weeks and log your pages. 300 pages each by the end. Share insights and recommendations! 📚",
    start_offset: -4,
    days: 21,
    cadence: :weekly,
    times_per_period: 2,
    unit: :pages,
    target_amount: 300,
    target_scope: :total,
    participants: %i[alice dora],
    check_ins: {
      alice: [
        {day: 2, message: "Round 2! Starting 'Project Hail Mary' 🚀", amount: 45},
        {day: 5, message: "Can't put it down 🤓", amount: 60}
      ],
      dora: [
        {day: 3, message: "'Klara and the Sun' ☀️", amount: 30}
      ]
    }
  },
  "00000000-0000-4000-8000-000000000003" => {
    title: "4-Week Meditation & Mindfulness(DEMO)",
    description: "Meditate four times a week, at least 10 minutes a sit. Find inner peace together! 🧘‍♂️✨",
    start_offset: -9,
    days: 28,
    cadence: :weekly,
    times_per_period: 4,
    unit: :minutes,
    target_amount: 10,
    target_scope: :each_time,
    participants: %i[bob charlie dora],
    check_ins: {
      bob: [
        {day: 1, message: "Started with 10 minutes of breathing. Feeling calm! 🧘‍♂️", amount: 10},
        {day: 2, message: "Tried guided meditation. Slept better! 😴", amount: 15},
        {day: 4, message: "Breathing before a big meeting 🫁", amount: 10},
        {day: 6, message: "Lunch break sit 🍃", amount: 10},
        {day: 8, message: "New week, sunset sit by the water 🌅", amount: 12, photo: :sunset_meditation,
         replies: [[:dora, "What a spot for it 😍"]]},
        {day: 10, message: "Meditated outdoors. Birds were a nice touch. 🐦", amount: 20, photo: :sunrise_arms}
      ],
      charlie: [
        {day: 1, message: "Day 1: Mind kept wandering, but I stuck with it. 🌱", amount: 10},
        {day: 3, message: "Used a meditation app. Helped a lot! 📱", amount: 12},
        {day: 5, message: "Felt more focused at work today. 💼", amount: 10},
        {day: 9, message: "Only three last week, catching up this one 🏃", amount: 15}
      ],
      dora: [
        {day: 1, message: "Lit a candle and meditated. Peaceful! 🕯️", amount: 15},
        {day: 2, message: "Shared my playlist with the group. 🎵", amount: 10},
        {day: 4, message: "Walking meditation by the river 🌊", amount: 20},
        {day: 7, message: "Morning sit with tea 🍵", amount: 15},
        {day: 8, message: "Week 2, let's go 🌿", amount: 10},
        {day: 9, message: "Did a body scan meditation. Relaxed! 😌", amount: 25, photo: :beach_yoga,
         replies: [[:charlie, "Need to try body scans, any app you'd recommend?"], [:dora, "Insight Timer, the free one 🙏"]]},
        {day: 10, message: "Three down this week ✨", amount: 10}
      ]
    },
    rewards: [
      {giver: :bob, receiver: :charlie, description: "Keep every week and I'll treat you to a spa day! 🧖‍♂️"},
      {giver: :dora, receiver: :bob, description: "I'll share my secret meditation playlist! 🎵"},
      {giver: :charlie, receiver: :dora, description: "Perfect attendance = herbal tea collection! 🍵"}
    ]
  },
  "00000000-0000-4000-8000-000000000005" => {
    title: "Couch to 5K(DEMO)",
    description: "Run three times a week for six weeks. Any pace, aim for 3 km a run. 🏃‍♀️",
    start_offset: -2,
    days: 42,
    cadence: :weekly,
    times_per_period: 3,
    unit: :km,
    target_amount: 3,
    target_scope: :each_time,
    participants: %i[dora],
    check_ins: {
      dora: [
        {day: 1, message: "First run in ages, walked a bit 🏃‍♀️", amount: 2.4},
        {day: 3, message: "Made it to 3.2 km without stopping! 🎉", amount: 3.2}
      ]
    }
  }
}

liking = Random.new(42)

challenge_data.each do |id, data|
  start = data[:start_offset].days.from_now.to_date

  challenge = ChallengeStory.create!(
    id:,
    previous_challenge_story_id: data[:previous],
    title: data[:title],
    description: data[:description],
    start:,
    finish: start + (data[:days] - 1).days,
    completed: data.fetch(:completed, false),
    cadence: data.fetch(:cadence, :daily),
    times_per_period: data.fetch(:times_per_period, 1),
    unit: data[:unit],
    target_amount: data[:target_amount],
    target_scope: data[:target_scope],
    created_at: start.in_time_zone
  )

  participants = data[:participants].to_h do |key|
    [key, challenge.challenge_participants.create!(user: users[key], status: :active)]
  end

  data[:check_ins].each do |key, entries|
    entries.each do |entry|
      date = start + (entry[:day] - 1).days
      hour = entry.fetch(:hour, 8)

      check_in = challenge.challenge_check_ins.create!(
        challenge_participant: participants[key],
        message: entry[:message],
        amount: entry[:amount],
        checked_in_on: date,
        created_at: not_after_now.call(date.in_time_zone.change(hour:), 24 - hour)
      ) { attach_demo_photo.call(it, entry[:photo]) if entry[:photo] }

      entry[:replies]&.each_with_index do |(replier, body), index|
        check_in.challenge_check_in_replies.create!(
          user: users[replier],
          body:,
          created_at: not_after_now.call(check_in.created_at + (index + 1) * 25.minutes, 5 - index)
        )
      end

      (data[:participants] - [key]).each do |liker|
        check_in.challenge_check_in_likes.create!(user: users[liker]) if liking.rand < 0.6
      end
    end
  end

  data[:rewards]&.each do |reward_data|
    reward = challenge.challenge_rewards.create!(
      giver: participants[reward_data[:giver]],
      receiver: participants[reward_data[:receiver]],
      description: reward_data[:description]
    )
    reward.fulfill! if reward_data[:fulfilled]
  end

  ChallengeStoryLike.create!(challenge_story: challenge, user: users[data[:participants].first])

  puts "✅ Created '#{challenge.title}' round #{challenge.round} with #{challenge.challenge_check_ins.count} check-ins, #{challenge.challenge_rewards.count} rewards"
end

# Badges come from the activity above, just as the nightly backfill would award them
users.each_value { BadgeAwardJob.perform_now(it, announce: false) }

puts "\n📊 Summary:"
print_counts.call
puts "\n🎉 Seeding complete!"
