# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in recording_studio_embeddable.gemspec
gemspec

# These gems are not published to RubyGems; resolve the gemspec pins from GitHub.
gem "flat_pack", ">= 0.1.364", github: "bowerbird-app/flatpack", tag: "v0.1.364"
gem "recording_studio", ">= 6.7.0", github: "bowerbird-app/RecordingStudio", tag: "v6.7.0"
gem "recording_studio_accessible", ">= 0.32.0", "< 1.0",
    github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.32.0"
# Attachable 0.23 depends on API. API depends on Moveable, which depends on Icons.
# None of those gems are on RubyGems.
gem "recording_studio_api", ">= 0.23.0",
    github: "bowerbird-app/RecordingStudio_api", tag: "v0.23.0"
gem "recording_studio_artifacts", ">= 0.4.7", "< 1.0",
    github: "bowerbird-app/RecordingStudio_artifacts", tag: "v0.4.7"
gem "recording_studio_attachable", ">= 0.23.0", "< 1.0",
    github: "bowerbird-app/RecordingStudio_attachable", tag: "v0.23.0"
gem "recording_studio_cache", ">= 0.6.3", "< 1.0",
    github: "bowerbird-app/RecordingStudio_cache", tag: "v0.6.3"
gem "recording_studio_icons", ">= 0.2.1",
    github: "bowerbird-app/RecordingStudio_icons", tag: "v0.2.1"
gem "recording_studio_logs", ">= 0.7.4", "< 1.0",
    github: "bowerbird-app/RecordingStudio_logs", tag: "v0.7.4"
gem "recording_studio_metrics", ">= 0.8.0", "< 1.0",
    github: "bowerbird-app/RecordingStudio_metrics",
    tag: "v0.8.0"
gem "recording_studio_moveable", ">= 4.1.1",
    github: "bowerbird-app/RecordingStudio_moveable", tag: "v4.1.1"
gem "recording_studio_publishable", ">= 0.14.0", "< 1.0",
    github: "bowerbird-app/RecordingStudio_publishable", tag: "v0.14.0"
gem "recording_studio_trashable", ">= 0.14.0", "< 1.0",
    github: "bowerbird-app/RecordingStudio_trashable", tag: "v0.14.0"
gem "view_component", ">= 4.14", "< 5"

gem "devise"

gem "puma", "~> 7.2.1"
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
