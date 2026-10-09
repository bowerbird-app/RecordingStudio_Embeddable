# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in recording_studio_embeddable.gemspec
gemspec

# These gems are not published to RubyGems; resolve the gemspec pins from GitHub.
gem "flat_pack", "~> 0.1.213", github: "bowerbird-app/flatpack", tag: "v0.1.213"
gem "recording_studio", "~> 4.2", github: "bowerbird-app/RecordingStudio", tag: "v4.4.0"
gem "recording_studio_accessible", "~> 0.13", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.13.0"
gem "recording_studio_artifacts", "~> 0.4.0",
    github: "bowerbird-app/RecordingStudio_artifacts", tag: "v0.4.0"
gem "recording_studio_attachable", "~> 0.13",
    github: "bowerbird-app/RecordingStudio_attachable", tag: "v0.13.0"
gem "recording_studio_publishable", "~> 0.4", github: "bowerbird-app/RecordingStudio_publishable", tag: "v0.6.0"

gem "devise"

gem "puma"
gem "sprockets-rails"

group :development, :test do
  gem "debug"
  gem "simplecov", require: false
end

group :development do
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
end
