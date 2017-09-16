Rails.application.routes.draw do
  resources :server_deploys
  resources :servers
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  root to: "servers#index"
end
