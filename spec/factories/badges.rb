FactoryBot.define do
  factory :badge do
    user
    kind { :first_check_in }
  end
end
