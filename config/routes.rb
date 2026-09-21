Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  scope "/sign/:workspace_id", as: :sign, module: :sign do
    get "/", to: "uploads#show", as: :upload
    get "/recipients", to: "recipients#show", as: :recipients
  end

  namespace :api do
    resources :envelopes, only: [ :create ] do
      post :charge_preview, on: :member, path: "charge-preview"
    end
  end
end
