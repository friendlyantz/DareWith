# DareWith

Bet on yourself. Daily challenges with friends and real stakes: check in with proof, and if you miss a day, you owe them. Live at [darewith.app](https://darewith.app). Repo name: `take-on-me`.

## What it does

**Challenges**
- Start from a template (Push-ups, Run, 100 km, Reading, Gym, Meditate, Fasting, Vice, Make bed) or write your own.
- Pick a length with chips (1–4 weeks, 30 days) or custom dates. Check-ins open on the start date; before then the challenge counts down.
- Goals are a yes/no habit or a count (reps, minutes, km, pages), per day or per week. Check-ins add up, so 30 + 20 reps meets "50 a day". The form works out what to count from the title as you type.
- Rounds can repeat automatically, with everyone still in carried over.

**Friends**
- Up to 4 people per challenge, invited with a short link (`darewith.app/c/k3Fx9aQm`) that shows a preview card in WhatsApp, iMessage and Instagram DMs.
- Likes, replies and nudges on check-ins.
- Doubts: friends can doubt a check-in for 48 hours, and the author replies with proof. If more than half doubt it (never in a pair), it stops counting.

**Stakes**
- Penalties: nothing, each miss, or whoever misses most ("Each miss: coffee for everyone"). The leaderboard tallies them, and they become pledges when the challenge closes.
- Rewards: pledge something to a friend for finishing, and mark it received from the last day.
- Challenges complete by themselves after everyone's grace day, with a finale card showing who owes what.

**Progress**
- Streaks, with a freeze earned every 7 days in a row that covers one missed day.
- "At this pace" forecasts and a leaderboard.
- Badges: First step, Warming up, One week strong, Habit formed, Comeback, Finisher, Flawless, Cheerleader, Good for it.
- A shareable progress card with the short link and a QR code.

**Staying in touch**
- Web push and an in-app Alerts list (bell with a live unread count).
- Evening check-in reminders and a weekly recap.
- Today screen: what's due, coming up, and just finished.

**Accounts**
- Passkeys (no username to type), email sign-in, and sign-in from another device.
- Installable as a PWA.
- Demo challenges on the landing page, and an admin overview.

## Roadmap

Ideas from the original plan that haven't shipped yet:

- **Measure it:** set success criteria (e.g. 10 users finish a challenge with 3+ check-ins in 2 weeks), and track check-ins and replies per challenge.
- **Discovery:** a trending or public challenges feed.
- **Insights:** best days and times, heat maps, comparing yourself with past challenges.
- **Social:** a group chat per challenge, an accountability score, custom milestones.
- **Growth:** build in public, invite-only beta, user stories.
- **Monetization:** premium tier (deeper insights, AI goal suggestions), reward marketplace, sponsored challenges with gyms and wellness brands.
- **Integrations:** health and fitness apps for automatic check-ins.

### Guiding principles

- **Gamify thoughtfully:** celebrate effort and consistency, not just results, and bring people back after a break.
- **Keep it social and supportive:** positive reinforcement and friends who keep you honest.
- **Minimize friction:** fast onboarding, one-tap check-ins, smart defaults per challenge type.
- **Make progress visible:** small steps should feel rewarding, and trends matter more than absolute numbers.

---

# Tools

- Ruby 3.4, Rails 8.1, Postgres, Hotwire (Turbo + Stimulus), importmap
- Solid Queue / Cache / Cable
- Tailwind + daisyUI 5
- WebAuthn passkeys, Web Push
- Docker, Kamal
- RSpec, FactoryBot, Capybara + Cuprite, SitePrism
- `standard`, `erb_lint`

```bash
bin/setup        # install, prepare the database, start the server
bin/dev          # server + Tailwind watcher
bundle exec rspec
bundle exec standardrb --fix
```

See `AGENTS.md` for code conventions.

# Debugging

```ruby
gem "debugger"

debugger(binding)

# ----------
gem "trace_location"

request = Rack::MockRequest.env_for('http://localhost:3000')

was_alloc = GC.stat[:total_allocated_objects] # the number of created Ruby objects

TraceLocation.trace(format: :log, methods: [:call]) do
  Rails.application.call(request)
end

new_alloc = GC.stat[:total_allocated_objects]
puts "Total allocations: #{new_alloc - was_alloc}"
```

# Credentials

ROTATABLE - ENV vars
FIXED - config/credentials.yml.enc

# WebPush

```ruby
wpn = WebPushNotification.order(:created_at).last
wpn.send_notification(
  title: "Hello!",
  body: "This is a test notification",
  icon: "/icon.png"
  )
```
