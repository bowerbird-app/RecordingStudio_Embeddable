# frozen_string_literal: true

RecordingStudioEmbeddable::Engine.routes.draw do
  namespace :management do
    resources :embeds, only: %i[edit update] do
      member do
        get :preview
        get :settings
        get :stats
      end
    end
  end

  get "embeds/:token", to: "embeds#show", as: :embed
end
