Rails.application.routes.draw do
  resources :server_deploys
  resources :servers
  post "/api/deploy_log", to: "api#deploy_log"
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  root to: "servers#index"

  resources :slack do
    collection do
      post :staging
      post :slash_super_staging
      post :super_staging_event
      post :super_staging_interactivity
    end
  end
end
