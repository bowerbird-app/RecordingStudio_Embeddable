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
    # Same eager-load pass as `bin/rails zeitwerk:check` (Zeitwerk::Loader.eager_load_all).
    # Do not use Rails.autoloaders.main.eager_load(force: true) here: FlatPack's
    # app/components sit on autoload_paths but not eager_load_paths, and force
    # loading them raises Zeitwerk::NameError unrelated to this engine.
    assert_nothing_raised do
      Zeitwerk::Loader.eager_load_all
    end
  end
end
