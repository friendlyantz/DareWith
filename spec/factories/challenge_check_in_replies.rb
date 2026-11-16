FactoryBot.define do
  factory :challenge_check_in_reply do
    user
    challenge_check_in
    body { "Nice one!" }
  end
end
