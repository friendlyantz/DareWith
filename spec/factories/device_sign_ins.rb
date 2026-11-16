FactoryBot.define do
  factory :device_sign_in do
    user_agent { "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0 Safari/537.36" }

    trait :approved do
      user
      state { :approved }
    end
  end
end
