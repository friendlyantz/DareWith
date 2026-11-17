FactoryBot.define do
  factory :challenge_nudge do
    sender factory: :challenge_participant
    receiver { association :challenge_participant, challenge_story: sender.challenge_story }
  end
end
