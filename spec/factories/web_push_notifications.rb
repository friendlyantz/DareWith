FactoryBot.define do
  factory :web_push_notification do
    user
    sequence(:endpoint) { |n| "https://push.example.com/subscription/#{n}" }
    auth_key { "auth-key" }
    p256dh_key { "p256dh-key" }
  end
end
