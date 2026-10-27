# frozen_string_literal: true

source "https://rubygems.org"

require_relative "test/support/widen_recording_studio_requirement"

# Specify your gem's dependencies in recording_studio_embeddable.gemspec
gemspec

# These gems are not published to RubyGems; resolve the gemspec pins from GitHub.
gem "flat_pack", ">= 0.1.315", github: "bowerbird-app/flatpack", ref: "1fcbafe94f8eb118f0a22182f63f5110fcc97a56"
gem "recording_studio", ">= 6.1.0", github: "bowerbird-app/RecordingStudio", tag: "v6.1.0"
gem "recording_studio_accessible", "~> 0.13", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.15.0"
gem "recording_studio_artifacts", "~> 0.4.0",
    github: "bowerbird-app/RecordingStudio_artifacts", tag: "v0.4.0"
gem "recording_studio_attachable", "~> 0.13",
    github: "bowerbird-app/RecordingStudio_attachable", tag: "v0.15.0"
gem "recording_studio_cache", "~> 0.5",
    github: "bowerbird-app/RecordingStudio_cache", tag: "v0.5.0"
gem "recording_studio_logs", ">= 0.4.1", "< 0.6",
    github: "bowerbird-app/RecordingStudio_logs", tag: "v0.5.0"
# Attachable 0.14+ depends on recording_studio_metrics (~> 0.2); pin from GitHub.
gem "recording_studio_metrics",
    github: "bowerbird-app/RecordingStudio_metrics",
    tag: "v0.2.0"
gem "recording_studio_publishable", "~> 0.4", github: "bowerbird-app/RecordingStudio_publishable", tag: "v0.8.0"
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
