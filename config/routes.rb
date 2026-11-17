Rails.application.routes.draw do
  resources :web_push_notifications, only: %i[create destroy] do
    delete :unsubscribe, on: :collection
  end
  # Development email preview
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?

  # Test-only route for signing in without WebAuthn
  get "test_sign_in/:user_id", to: "webauthn/sessions#test_sign_in", as: :test_sign_in if Rails.env.test?

  resource :today, only: %i[show], controller: "today"
  resource :profile, only: %i[show update], path: "me"
  resource :avatar, only: %i[update destroy]

  resources :challenge_stories, only: %i[index show new create edit update] do
    member do
      patch :complete
    end
    resources :challenge_check_ins, only: %i[new create destroy]
    resources :challenge_rewards, only: %i[index new create show] do
      member do
        patch :fulfill
        patch :cancel
      end
    end
    resource :challenge_story_like, only: %i[create destroy]
  end

  resources :challenge_check_ins, only: %i[index] do
    resource :challenge_check_in_like, only: %i[create destroy]
    resources :challenge_check_in_replies, only: %i[create]
  end

  resources :challenge_participants, only: %i[create destroy]
  get "home/index"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", :as => :rails_health_check
  mount Challenge::Engine, at: "/challenge"
  root "home#index"

  namespace :webauthn do
    resource :session, only: %i[new create destroy] do
      post :callback, on: :collection
    end

    resource :registration, only: %i[new create] do
      post :callback, on: :collection
    end
  end

  namespace :email do
    resource :session, only: %i[new create] do
      get :verify, on: :collection
      post :confirm, on: :collection
    end
    resource :registration, only: %i[new create]
  end

  namespace :admin do
    root "dashboards#show"
    resources :users, only: %i[show destroy] do
      resource :sign_in_link, only: %i[create]
      resource :notification, only: %i[create]
    end
    resources :challenge_stories, only: %i[destroy]
  end

  resource :device_sign_in, only: %i[show create]
  resource :device_sign_in_approval, only: %i[new create], path: "device_sign_in/approve"

  resources :credentials, only: %i[index create destroy] do
    post :callback, on: :collection
  end

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  get "manifest" => "rails/pwa#manifest", :as => :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", :as => :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
