FactoryBot.define do
  factory :email_signup do
    sequence(:email) { "signup#{it}@example.com" }
    code_digest { Digest::SHA256.hexdigest("123456") }
    code_sent_at { Time.current }
  end
end
