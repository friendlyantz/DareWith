FactoryBot.define do
  factory :challenge_participant do
    user
    challenge_story
    name { user.username }
    status { :active }
    # Joined when the challenge started, unless that's still to come
    created_at { [challenge_story.start.in_time_zone, Time.current].min }

    trait :inactive do
      status { :inactive }
    end
  end
end
