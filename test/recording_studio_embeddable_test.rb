# frozen_string_literal: true

require "test_helper"
require "active_record"
require_relative "../app/models/recording_studio_embeddable/application_record"
require_relative "../app/models/recording_studio_embeddable/embed"

class RecordingStudioEmbeddableTest < Minitest::Test
  FakeClass = Struct.new(:recording_studio_embeddable_options) do
    def self.model_name = ActiveModel::Name.new(self, nil, "FakePage")
  end

  FakeRecordable = Struct.new(:published) do
    def self.recording_studio_embeddable_options
      { enabled: true, renderer: "macro/renderer", require_publishable: true }
    end

    def self.model_name = ActiveModel::Name.new(self, nil, "FakePage")

    def published?
      published
    end
  end

  FakeRecording = Struct.new(:recordable, :updated_at)

  class FakePublishableRecordable
    def self.model_name = ActiveModel::Name.new(self, nil, "FakeArticle")

    def self.recording_studio_publishable_options
      { public_controller: "articles", public_action: :show }
    end
  end

  class FakeExplicitPublicRouteRecordable
    def self.model_name = ActiveModel::Name.new(self, nil, "FakeArticle")

    def self.recording_studio_embeddable_options
      { embed_controller: "articles", embed_action: :show }
    end
  end

  class FakeCachedRecordable
    def self.model_name = ActiveModel::Name.new(self, nil, "FakePage")

    def self.recording_studio_embeddable_options
      { cache: { max_age: 1800, stale_while_revalidate: 120 } }
    end
  end

  class FakeNonCachedRecordable
    def self.model_name = ActiveModel::Name.new(self, nil, "FakePage")

    def self.recording_studio_embeddable_options
      { cache: false }
    end
  end

  class FakeThemeRecordable
    def self.model_name = ActiveModel::Name.new(self, nil, "FakePage")

    def self.recording_studio_embeddable_options
      {
        embed_theme: {
          font_family: "serif",
          radius_scale: "lg"
        }
      }
    end
  end

  def setup
    RecordingStudioEmbeddable.reset_configuration!
  end

  def test_version_and_engine_are_renamed
    assert_equal "0.1.0", RecordingStudioEmbeddable::VERSION
    assert_equal RecordingStudioEmbeddable, RecordingStudioEmbeddable::Engine.railtie_namespace
  end

  def test_configuration_defaults_fail_closed_for_publishable_and_domains
    config = RecordingStudioEmbeddable.configuration

    assert_equal [], config.allowed_embedder_domains
    assert_equal [], config.blocked_embedder_domains
    assert_equal true, config.require_publishable
    assert_equal :null, config.rate_limiter
  end

  def test_capability_key_and_options
    capability = RecordingStudio::Capabilities::Embeddable.to(embed_controller: "pages", embed_action: :show)

    assert_equal :embeddable, capability.key
    assert_equal true, capability.options[:enabled]
    assert_equal "pages", capability.options[:embed_controller]
    assert_equal :show, capability.options[:embed_action]
  end

  def test_token_generation_is_url_safe_and_stable_length
    token = RecordingStudioEmbeddable::Embed.generate_token

    assert_match(/\A[A-Za-z0-9]{32}\z/, token)
  end

  def test_renderer_prefers_capability_over_macro
    recordable = FakeRecordable.new(true)
    def recordable.recording_studio_capabilities
      [RecordingStudio::Capabilities::Embeddable.to(renderer: "capability/renderer")]
    end

    assert_equal "capability/renderer",
                 RecordingStudioEmbeddable::Renderer.resolve(FakeRecording.new(recordable, Time.now), nil)
  end

  def test_renderer_uses_safe_fallback_not_publishable_renderer
    recordable = Object.new
    recording = FakeRecording.new(recordable, Time.now)

    assert_equal "recording_studio_embeddable/embeds/default",
                 RecordingStudioEmbeddable::Renderer.resolve(recording, nil)
  end

  def test_renderer_convention_prefers_show_for_publishable_recordables
    recording = FakeRecording.new(FakePublishableRecordable.new, Time.now)

    details = RecordingStudioEmbeddable::Renderer.convention_for(recording)

    assert_equal :show, details[:action]
    assert_equal "fake_articles/show", details[:template]
    assert_equal "fake_articles/embed", details[:fallback_template]
    assert_equal "recording_studio_embeddable/embed", details[:layout]
  end

  def test_renderer_convention_uses_embed_for_non_publishable_recordables
    recording = FakeRecording.new(FakeRecordable.new(true), Time.now)

    details = RecordingStudioEmbeddable::Renderer.convention_for(recording)

    assert_equal :embed, details[:action]
    assert_equal "fake_pages/embed", details[:template]
    assert_nil details[:fallback_template]
    assert_equal "recording_studio_embeddable/embed", details[:layout]
  end

  def test_renderer_convention_prefers_explicit_public_route_options
    recording = FakeRecording.new(FakeExplicitPublicRouteRecordable.new, Time.now)

    details = RecordingStudioEmbeddable::Renderer.convention_for(recording)

    assert_equal :show, details[:action]
    assert_equal "articles/show", details[:template]
    assert_equal "articles/embed", details[:fallback_template]
    assert_equal "recording_studio_embeddable/embed", details[:layout]
  end

  def test_renderer_layout_for_uses_embed_layout_by_default
    recording = FakeRecording.new(FakeRecordable.new(true), Time.now)

    assert_equal "recording_studio_embeddable/embed",
                 RecordingStudioEmbeddable::Renderer.layout_for(recording, nil)
  end

  def test_renderer_embed_theme_merges_global_recordable_and_embed_overrides
    RecordingStudioEmbeddable.configuration.embed_theme = {
      font_family: "sans",
      text_color: "#111827",
      radius_scale: "sm"
    }
    recording = FakeRecording.new(FakeThemeRecordable.new, Time.now)
    embed = Struct.new(:appearance).new({ "text_color" => "#ff0000", "padding_scale" => "xl" })

    theme = RecordingStudioEmbeddable::Renderer.embed_theme_for(recording, embed: embed)

    assert_equal "serif", theme[:font_family]
    assert_equal "#ff0000", theme[:text_color]
    assert_equal "lg", theme[:radius_scale]
    assert_equal "xl", theme[:padding_scale]
  end

  def test_styling_validator_rejects_unknown_keys_and_normalizes_values
    result = RecordingStudioEmbeddable::Styling::ValidateOverrides.call(
      values: {
        "text_color" => "#ABC",
        "max_width" => "900",
        "unknown_token" => "oops"
      }
    )

    refute result.valid?
    assert_equal "#aabbcc", result.cleaned["text_color"]
    assert_equal 900, result.cleaned["max_width"]
    assert_equal "is not an editable style option", result.errors["unknown_token"]
  end

  def test_styling_resolver_tracks_precedence_sources
    RecordingStudioEmbeddable.configuration.embed_theme = {
      text_color: "#111111",
      padding_scale: "sm"
    }

    recordable = FakeThemeRecordable.new
    recording = FakeRecording.new(recordable, Time.now)
    embed = Struct.new(:appearance).new({ "padding_scale" => "xl" })

    result = RecordingStudioEmbeddable::Styling::ResolveTheme.call(recording: recording, embed: embed)

    assert_equal "#111111", result.values[:text_color]
    assert_equal "xl", result.values[:padding_scale]
    assert_equal "recordable", result.sources[:font_family]
    assert_equal "embed", result.sources[:padding_scale]
  end

  def test_recordable_defaults_service_falls_back_to_recordable_options
    recordable = FakeThemeRecordable.new
    recording = FakeRecording.new(recordable, Time.now)

    result = RecordingStudioEmbeddable::Styling::RecordableDefaults.call(recording: recording)

    assert_equal "RecordingStudioEmbeddableTest::FakeThemeRecordable", result[:recordable_type]
    assert_equal "serif", result[:defaults]["font_family"]
    assert_equal "lg", result[:defaults]["radius_scale"]
    assert_equal true, result[:allow_custom_styling]
  end

  def test_resolver_uses_recordable_defaults_service_layer
    stubbed = lambda do |recording:|
      {
        recordable_type: recording.recordable.class.name,
        defaults: { "font_family" => "mono", "text_color" => "#222222" },
        allow_custom_styling: true,
        profile: nil
      }
    end

    RecordingStudioEmbeddable::Styling::RecordableDefaults.stub(:call, stubbed) do
      recording = FakeRecording.new(FakeThemeRecordable.new, Time.now)
      embed = Struct.new(:appearance).new({ "text_color" => "#ff0000" })

      result = RecordingStudioEmbeddable::Styling::ResolveTheme.call(recording: recording, embed: embed)

      assert_equal "mono", result.values[:font_family]
      assert_equal "#ff0000", result.values[:text_color]
      assert_equal "recordable", result.sources[:font_family]
      assert_equal "embed", result.sources[:text_color]
    end
  end

  def test_domain_policy_validates_and_matches_wildcards
    embed = Struct.new(:allowed_domains, :blocked_domains).new(["*.example.com"], ["blocked.example.com"])

    assert RecordingStudioEmbeddable::Security::DomainPolicy.valid_domain?("*.example.com")
    assert RecordingStudioEmbeddable::Security::DomainPolicy.new(embed: embed, origin: "https://docs.example.com").allowed?
    refute RecordingStudioEmbeddable::Security::DomainPolicy.new(embed: embed, origin: "https://blocked.example.com").allowed?
  end

  def test_publishable_gate_fails_closed_without_helper
    embed = Struct.new(:enabled?, :allowed_domains, :blocked_domains).new(true, ["example.com"], [])
    request = Struct.new(:referer, :remote_ip, :user_agent) do
      def get_header(_) = "https://example.com"
    end.new("https://example.com", "127.0.0.1", "test")
    recording = FakeRecording.new(Object.new, Time.now)

    result = RecordingStudioEmbeddable::Security::PublicAccess.call(embed: embed, request: request,
                                                                    recording: recording)

    refute result.allowed?
    assert_equal :not_found, result.status
  end

  def test_domain_policy_csp_includes_apex_for_wildcards
    embed = Struct.new(:allowed_domains, :blocked_domains).new(["*.example.com"], [])

    sources = RecordingStudioEmbeddable::Security::DomainPolicy.new(embed: embed).frame_ancestors

    assert_includes sources, "https://example.com"
    assert_includes sources, "https://*.example.com"
  end

  def test_normalize_payload_redacts_embed_token_and_query
    request = Struct.new(:remote_ip, :user_agent, :referer, :host, :path, :fullpath, :request_method) do
      def get_header(_) = ""
    end.new("127.0.0.1", "test", "", "example.test", "/recording_studio_embeddable/embeds/raw-token",
            "/recording_studio_embeddable/embeds/raw-token?secret=1", "GET")

    payload = RecordingStudioEmbeddable::Services::NormalizePayload.call(request)

    assert_equal "/recording_studio_embeddable/embeds/[token]", payload[:request_path]
    refute_includes payload[:request_path], "raw-token"
    refute_includes payload[:request_path], "secret"
  end

  def test_cache_policy_merges_defaults
    RecordingStudioEmbeddable.configuration.cache_policy = { max_age: 60 }

    assert_equal({ enabled: false, public: true, max_age: 60, stale_while_revalidate: 60 },
                 RecordingStudioEmbeddable::CachePolicy.resolve(embed: nil, recording: nil))
  end

  def test_cache_policy_enables_cache_with_boolean_flag
    klass = Class.new do
      def self.model_name = ActiveModel::Name.new(self, nil, "FakePage")

      def self.recording_studio_embeddable_options
        { cache: true }
      end
    end
    recording = FakeRecording.new(klass.new, Time.now)

    assert_equal true, RecordingStudioEmbeddable::CachePolicy.resolve(embed: nil, recording: recording)[:enabled]
  end

  def test_cache_policy_allows_per_recordable_cache_overrides
    recording = FakeRecording.new(FakeCachedRecordable.new, Time.now)

    assert_equal(
      { enabled: true, public: true, max_age: 1800, stale_while_revalidate: 120 },
      RecordingStudioEmbeddable::CachePolicy.resolve(embed: nil, recording: recording)
    )
  end

  def test_cache_policy_can_disable_caching_for_recordable
    recording = FakeRecording.new(FakeNonCachedRecordable.new, Time.now)

    assert_equal false, RecordingStudioEmbeddable::CachePolicy.resolve(embed: nil, recording: recording)[:enabled]
  end

  def test_view_logging_uses_digests_not_raw_ip
    digest = RecordingStudioEmbeddable::Services::LogView.digest("127.0.0.1")

    refute_equal "127.0.0.1", digest
    assert_match(/\A[0-9a-f]{64}\z/, digest)
  end

  def test_dummy_app_surface_is_wired
    routes = File.read(File.expand_path("dummy/config/routes.rb", __dir__))
    page = File.read(File.expand_path("dummy/app/models/page.rb", __dir__))

    assert_includes routes, "mount RecordingStudioEmbeddable::Engine"
    assert_includes page, "RecordingStudio::Capabilities::Embeddable.to"
    assert File.exist?(File.expand_path("dummy/app/views/pages/embed.html.erb", __dir__))
  end

  def test_generators_are_renamed
    assert File.exist?(File.expand_path("../lib/generators/recording_studio_embeddable/install/install_generator.rb",
                                        __dir__))
    assert File.exist?(File.expand_path(
                         "../lib/generators/recording_studio_embeddable/migrations/migrations_generator.rb", __dir__
                       ))
  end

  def test_migration_enforces_one_active_embed_child_per_parent
    migration = File.read(File.expand_path("../db/migrate/20250101000001_create_recording_studio_embeddable_embeds.rb",
                                           __dir__))

    assert_includes migration, "index_rs_unique_active_embed_per_parent"
    assert_includes migration, "active_embed_recording_index_predicate"
    assert_includes migration, "column_exists?(:recording_studio_recordings, :trashed_at)"
  end

  def test_view_migration_uses_postgresql_safe_index_names
    migration = File.read(File.expand_path("../db/migrate/20250101000002_create_recording_studio_embeddable_views.rb",
                                           __dir__))

    assert_includes migration, "idx_rse_views_embed_viewed_at"
    refute_includes migration, "index_recording_studio_embeddable_views_on_embed_id_and_viewed_at"
  end

  def test_recording_schema_detection_supports_recording_studio_versions_without_trashed_at
    with_stubbed_recording_class(column_names: %w[id parent_recording_id]) do
      refute RecordingStudioEmbeddable.recording_has_trashed_at?
    end
  end

  def test_recording_schema_detection_supports_legacy_recording_studio_versions_with_trashed_at
    with_stubbed_recording_class(column_names: %w[id parent_recording_id trashed_at]) do
      assert RecordingStudioEmbeddable.recording_has_trashed_at?
    end
  end

  private

  def with_stubbed_recording_class(column_names:)
    previous = RecordingStudio.const_defined?(:Recording, false) ? RecordingStudio.const_get(:Recording) : nil
    RecordingStudio.send(:remove_const, :Recording) if previous
    recording_class = Class.new do
      define_singleton_method(:column_names) { column_names }
    end
    RecordingStudio.const_set(:Recording, recording_class)
    yield
  ensure
    RecordingStudio.send(:remove_const, :Recording) if RecordingStudio.const_defined?(:Recording, false)
    RecordingStudio.const_set(:Recording, previous) if previous
  end
end
