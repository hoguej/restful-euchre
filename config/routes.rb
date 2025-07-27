Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get 'up' => 'rails/health#show', as: :rails_health_check

  # Game endpoints
  resources :games, param: :code, only: %i[create show] do
    member do
      post :join
      post :action
      get :players
    end

    collection do
      get :simulate
    end
  end
end
