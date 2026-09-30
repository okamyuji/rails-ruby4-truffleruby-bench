Rails.application.routes.draw do
  get "up" => "rails/health#show"
  resources :articles, only: %i[index show]
  namespace :api do
    resources :articles, only: %i[index create]
  end
end
