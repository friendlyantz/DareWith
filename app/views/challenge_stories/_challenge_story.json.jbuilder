json.extract! challenge_story, :id, :title, :description, :start, :finish, :cadence, :times_per_period, :unit, :target_amount, :target_scope, :created_at, :updated_at
json.url challenge_story_url(challenge_story, format: :json)
