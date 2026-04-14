Rails.application.routes.draw do
  root "dashboard#index"

  post "snoo/connect", to: "dashboard#connect"
  post "snoo/disconnect", to: "dashboard#disconnect"
  post "snoo/controls/hold", to: "dashboard#update_hold", as: :snoo_hold
  post "snoo/controls/level", to: "dashboard#change_level", as: :snoo_level
  post "snoo/controls/white_noise", to: "dashboard#update_white_noise", as: :snoo_white_noise

  get "up" => "rails/health#show", as: :rails_health_check
end
