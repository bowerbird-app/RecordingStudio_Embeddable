# frozen_string_literal: true

# The root Gemfile still pins recording_studio_artifacts tag v0.4.4, whose
# gemspec declares recording_studio ~> 4.2. That range rejects 6.3.0. The
# dummy Gemfile pins artifacts v0.4.5 (>= 4.2, < 7) and does not load this
# file. Rewrite the requirement when Bundler reads the root gemspecs.
module WidenRecordingStudioRequirement
  COMPATIBLE_VERSION = Gem::Version.new("6.3.0")
  WIDENED = Gem::Requirement.new(">= 4.1")

  module SpecificationDependencies
    def dependencies
      deps = super
      WidenRecordingStudioRequirement.widen_all(deps)
      deps
    end
  end

  def self.widen_all(deps)
    deps.each do |dependency|
      next unless dependency.name == "recording_studio"

      requirement = dependency.requirement
      next if requirement.satisfied_by?(COMPATIBLE_VERSION)

      dependency.instance_variable_set(:@requirement, WIDENED)
    end
  end
end

Gem::Specification.prepend(WidenRecordingStudioRequirement::SpecificationDependencies)
