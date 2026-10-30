# frozen_string_literal: true

source "https://rubygems.org"

require_relative "test/support/widen_recording_studio_requirement"

# Specify your gem's dependencies in recording_studio_embeddable.gemspec
gemspec

# These gems are not published to RubyGems; resolve the gemspec pins from GitHub.
gem "flat_pack", ">= 0.1.331", github: "bowerbird-app/flatpack", tag: "v0.1.331"
gem "recording_studio", ">= 6.3.0", github: "bowerbird-app/RecordingStudio", tag: "v6.3.0"
gem "recording_studio_accessible", "~> 0.23", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.23.1"
# Tag v0.4.4 still ships gem VERSION 0.4.0, so the constraint stays ~> 0.4.0.
gem "recording_studio_artifacts", "~> 0.4.0",
    github: "bowerbird-app/RecordingStudio_artifacts", tag: "v0.4.4"
gem "recording_studio_attachable", "~> 0.22",
    github: "bowerbird-app/RecordingStudio_attachable", tag: "v0.22.0"
gem "recording_studio_cache", "~> 0.6",
    github: "bowerbird-app/RecordingStudio_cache", tag: "v0.6.0"
gem "recording_studio_logs", ">= 0.7.1", "< 1.0",
    github: "bowerbird-app/RecordingStudio_logs", tag: "v0.7.1"
gem "recording_studio_metrics", ">= 0.7.0", "< 1.0",
    github: "bowerbird-app/RecordingStudio_metrics",
    tag: "v0.7.0"
gem "recording_studio_publishable", "~> 0.12", github: "bowerbird-app/RecordingStudio_publishable", tag: "v0.12.0"
gem "recording_studio_trashable", "~> 0.10",
    github: "bowerbird-app/RecordingStudio_trashable", tag: "v0.12.0"
gem "view_component", ">= 4.14", "< 5"

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
