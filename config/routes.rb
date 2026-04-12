Rails.application.routes.draw do
  root "dashboard#index"

  post "snoo/connect", to: "dashboard#connect"
  post "snoo/disconnect", to: "dashboard#disconnect"

  get "up" => "rails/health#show", as: :rails_health_check
end
