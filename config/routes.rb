# frozen_string_literal: true

RecordingStudioEmbeddable::Engine.routes.draw do
  namespace :management do
    resources :embeds, only: %i[edit update] do
      member do
        get :preview
        get :styling
        patch :styling, action: :update_styling
        get :settings
        get :floating
        patch :floating, action: :update_floating
        get :stats
      end
    end
  end

  get "widget.js", to: "widget_scripts#show", as: :widget_script
  get "widget_bridge.js", to: "widget_bridges#show", as: :widget_bridge
  get "embeds/:token", to: "embeds#show", as: :embed
  get "embeds/:token/launcher", to: "launchers#show", as: :embed_launcher
  match "embeds/:token/launcher", to: "launchers#preflight", via: :options
end
