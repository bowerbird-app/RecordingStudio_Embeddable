# frozen_string_literal: true

# Artifacts 0.4.4 still declares `recording_studio` `~> 4.2`. Dummy pins for
# API 0.5.5 also declare `~> 4.2`. Those ranges reject 6.3.0. Rewrite the
# requirement on the existing dependency object when Bundler reads the gemspec.
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
