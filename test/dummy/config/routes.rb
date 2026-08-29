Rails.application.routes.draw do
  require "recording_studio_attachable"
  require "recording_studio_publishable"

  devise_for :users
  mount RecordingStudioAttachable::Engine, at: "/recording_studio_attachable"

  # RecordingStudio engine is data/API-focused and has no browser root route.
  # Redirect the base path to the app home.
  get "/recording_studio", to: redirect("/"), as: nil
  mount RecordingStudio::Engine, at: "/recording_studio"
  mount RecordingStudioEmbeddable::Engine, at: "/recording_studio_embeddable"
  mount RecordingStudioPublishable::Engine, at: "/"

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  get "docs/install", to: "docs#install", as: :docs_install
  get "docs/config", to: "docs#configuration", as: :docs_config
  get "docs/recordable_types", to: "docs#recordable_types", as: :docs_recordable_types
  get "docs/recordings_tree", to: "docs#recordings_tree", as: :docs_recordings_tree
  get "docs/gem_views", to: "docs#gem_views", as: :docs_gem_views
  get "docs/methods", to: "docs#methods", as: :docs_methods
  get "articles/:id", to: "articles#show", as: :article
  get "articles/:id/embed", to: "articles#embed", as: :article_embed
  get "documents/:id", to: "documents#show", as: :document
  get "pages/:id/embed", to: "pages#embed", as: :page_embed
  get "/dummy/pages/new", to: "dummy_pages#new", as: :new_dummy_page
  post "/dummy/pages", to: "dummy_pages#create", as: :dummy_pages
  get "/dummy/pages/:id/edit", to: "dummy_pages#edit", as: :edit_dummy_page
  patch "/dummy/pages/:id", to: "dummy_pages#update", as: :dummy_page
  get "/dummy/articles/:id/edit", to: "dummy_articles#edit", as: :edit_dummy_article
  patch "/dummy/articles/:id", to: "dummy_articles#update", as: :dummy_article
  get "/dummy/documents/:id/edit", to: "dummy_documents#edit", as: :edit_dummy_document
  patch "/dummy/documents/:id", to: "dummy_documents#update", as: :dummy_document

  # Defines the root path route ("/")
  root "home#index"
end
