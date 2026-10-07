# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in recording_studio_embeddable.gemspec
gemspec

# These gems are not published to RubyGems; resolve the gemspec pins from GitHub.
gem "flat_pack", "~> 0.1.198", github: "bowerbird-app/flatpack", tag: "v0.1.198"
gem "recording_studio", "~> 4.2", github: "bowerbird-app/RecordingStudio", tag: "v4.2.2"
gem "recording_studio_accessible", "~> 0.11", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.11.1"
# Upstream release: https://github.com/bowerbird-app/RecordingStudio_artifacts/releases/tag/v0.3.0
# Repo is private (siblings are public), so CI cannot fetch via github: + tag with
# BOWERBIRD_ORG_CI_TOKEN. Vendored at v0.3.0 — switch to github tag when public.
gem "recording_studio_artifacts", "~> 0.3.0", path: "vendor/recording_studio_artifacts"
gem "recording_studio_publishable", "~> 0.4", github: "bowerbird-app/RecordingStudio_publishable", tag: "v0.4.2"

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
