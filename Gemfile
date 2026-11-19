# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in recording_studio_embeddable.gemspec
gemspec

# These gems are not published to RubyGems; resolve the gemspec pins from GitHub.
gem "flat_pack", "~> 0.2", github: "bowerbird-app/flatpack", tag: "v0.2.0"
gem "recording_studio", "~> 7.8", github: "bowerbird-app/RecordingStudio", tag: "v7.8.0"
gem "recording_studio_accessible", "~> 0.58",
    github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.58.0"
# Attachable 0.34 depends on API >= 1.1. API depends on Moveable, which depends on Icons.
# None of those gems are on RubyGems.
gem "recording_studio_api", "~> 1.21",
    github: "bowerbird-app/RecordingStudio_api", tag: "v1.21.2"
# Artifacts 0.4.7 requires recording_studio < 7. 0.6.0 is the current pin.
gem "recording_studio_artifacts", "~> 0.6",
    github: "bowerbird-app/RecordingStudio_artifacts", tag: "v0.6.0"
gem "recording_studio_attachable", "~> 0.34",
    github: "bowerbird-app/RecordingStudio_attachable", tag: "v0.34.0"
gem "recording_studio_cache", "~> 0.8",
    github: "bowerbird-app/RecordingStudio_cache", tag: "v0.8.0"
gem "recording_studio_icons", "~> 0.5",
    github: "bowerbird-app/RecordingStudio_icons", tag: "v0.5.0"
gem "recording_studio_logs", "~> 0.9",
    github: "bowerbird-app/RecordingStudio_logs", tag: "v0.9.0"
gem "recording_studio_metrics", "~> 0.10",
    github: "bowerbird-app/RecordingStudio_metrics",
    tag: "v0.10.0"
gem "recording_studio_moveable", "~> 6.1",
    github: "bowerbird-app/RecordingStudio_moveable", tag: "v6.1.0"
gem "recording_studio_publishable", "~> 1.5",
    github: "bowerbird-app/RecordingStudio_publishable", tag: "v1.5.0"
gem "recording_studio_trashable", "~> 1.3",
    github: "bowerbird-app/RecordingStudio_trashable", tag: "v1.3.0"
gem "view_component", ">= 4.14", "< 5"

gem "devise"

gem "puma", "8.1.0"
gem "sprockets-rails"

group :development, :test do
  gem "bundler-audit", require: false
  gem "debug"
  gem "simplecov", require: false
end

group :development do
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
end
