# frozen_string_literal: true

require_relative "lib/recording_studio_embeddable/version"

Gem::Specification.new do |spec|
  spec.name        = "recording_studio_embeddable"
  spec.version     = RecordingStudioEmbeddable::VERSION
  spec.authors     = ["Bowerbird"]
  spec.homepage    = "https://github.com/bowerbird-app/RecordingStudio_Embeddable"
  spec.summary     = "Public embed addon for Recording Studio"
  spec.description = "A Rails isolated engine that adds secure, opt-in public iframe embeds " \
                     "to Recording Studio recordings."
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "flat_pack", "~> 0.1.141"
  spec.add_dependency "rails", "~> 8.1.0"
  spec.add_dependency "recording_studio", "~> 4.2"
  spec.add_dependency "recording_studio_accessible", "~> 0.7.0"
  spec.add_dependency "recording_studio_publishable", "~> 0.2.0"
end
