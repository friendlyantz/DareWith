FactoryBot.define do
  factory :notification do
    user
    title { "Sam nudged you 👋" }
    path { "/today" }
  end
end
