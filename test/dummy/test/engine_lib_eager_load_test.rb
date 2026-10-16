# frozen_string_literal: true

require "test_helper"

# Hosts used to strip this engine's lib/ from eager_load_paths so Zeitwerk would
# not load generators and classic-required gem files as app constants. Prove the
# engine no longer puts lib/ on those paths and that dummy eager load is clean.
class EngineLibEagerLoadTest < ActiveSupport::TestCase
  test "engine lib is not on host eager load or autoload paths" do
    lib = RecordingStudioEmbeddable::Engine.root.join("lib").to_s
    eager = Rails.application.config.eager_load_paths.map(&:to_s)
    autoload = Rails.application.config.autoload_paths.map(&:to_s)

    refute_includes eager, lib,
                    "RecordingStudioEmbeddable must not add lib/ to eager_load_paths"
    refute_includes autoload, lib,
                    "RecordingStudioEmbeddable must not add lib/ to autoload_paths"
  end

  test "dummy app eager loads with Zeitwerk without stripping engine lib" do
    assert_nothing_raised do
      Rails.application.eager_load!
      Rails.autoloaders.each(&:eager_load)
    end
  end
end
