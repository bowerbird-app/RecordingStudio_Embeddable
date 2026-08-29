# frozen_string_literal: true

require "test_helper"
require "active_record"
require_relative "../app/helpers/recording_studio_embeddable/embed_layout_helper"
require_relative "../app/models/recording_studio_embeddable/application_record"
require_relative "../app/models/recording_studio_embeddable/embeddable_view_log"
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
        customizable_embed_styles: {
          font_family: {
            label: "Font",
            css_property: "font-family",
            input: :font_select,
            default: "serif"
          },
          text_color: {
            label: "Text color",
            css_variable: "--surface-content-color",
            input: :color,
            default: "#111827"
          },
          padding_scale: {
            label: "Padding",
            css_property: "padding",
            input: :select,
            choices: [%w[Small sm], ["Extra large", "xl"]]
          },
          radius_scale: {
            label: "Corner radius",
            css_property: "border-radius",
            input: :select,
            choices: [%w[Small sm], %w[Large lg]],
            default: "lg"
          }
        }
      }
    end
  end

  class FakeCustomizableRecordable
    def self.model_name = ActiveModel::Name.new(self, nil, "FakePage")

    def self.recording_studio_embeddable_options
      {
        customizable_embed_styles: {
          background_color: {
            label: "Background",
            css_variable: "--surface-background-color",
            input: :color,
            default: "#fafafa"
          },
          max_width: {
            label: "Max width",
            css_property: "max-width",
            input: :select,
            choices: [%w[Small 640px], { label: "Large", value: "960px" }],
            default: "960px"
          },
          font_family: {
            label: "Font",
            css_property: "font-family",
            input: :font_select
          }
        }
      }
    end
  end

  def setup
    RecordingStudioEmbeddable.reset_configuration!
  end

  def test_version_and_engine_are_renamed
    assert_equal "0.1.2", RecordingStudioEmbeddable::VERSION
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

  def test_recording_studio_embeddable_enables_embeddable_capability
    klass = Class.new do
      def self.name = "CapabilityProbePage"

      include RecordingStudioEmbeddable::Recordable
    end

    enabled = []
    fake_studio = Module.new do
      define_singleton_method(:enable_capability) do |capability, on:|
        enabled << [capability, on]
      end

      define_singleton_method(:set_capability_options) do |_capability, on:, **_opts|
        on
      end
    end

    original = Object.const_get(:RecordingStudio) if Object.const_defined?(:RecordingStudio)
    Object.send(:remove_const, :RecordingStudio) if Object.const_defined?(:RecordingStudio)
    Object.const_set(:RecordingStudio, fake_studio)

    begin
      klass.recording_studio_embeddable(embed_controller: "pages", embed_action: :embed)
    ensure
      Object.send(:remove_const, :RecordingStudio)
      Object.const_set(:RecordingStudio, original) if original
    end

    assert_includes enabled, [:embeddable, klass]
    assert_equal true, klass.recording_studio_embeddable_options[:enabled]
    assert_equal "pages", klass.recording_studio_embeddable_options[:embed_controller]
    assert_equal :embed, klass.recording_studio_embeddable_options[:embed_action]
  end

  def test_token_generation_is_url_safe_and_stable_length
    token = RecordingStudioEmbeddable::Embed.generate_token

    assert_match(/\A[A-Za-z0-9]{32}\z/, token)
  end

  def test_embed_code_uses_embed_max_width_for_iframe_width
    recording = Object.new
    recording.extend(RecordingStudioEmbeddable::RecordingMethods)
    recording.define_singleton_method(:embed_public_url) { |**| "https://example.com/embed" }
    recording.define_singleton_method(:embed) do
      Struct.new(:appearance, :sizing).new({}, { "width" => "100px", "height" => "480px" })
    end

    html = recording.embed_code(title: "Embedded recording")

    assert_includes html, "width:100px"
    assert_includes html, "height:480px"
    assert_includes html, "max-width:100%"
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

  def test_renderer_embed_theme_merges_recordable_defaults_and_embed_overrides
    recording = FakeRecording.new(FakeThemeRecordable.new, Time.now)
    embed = Struct.new(:appearance).new({ "text_color" => "#ff0000", "padding_scale" => "xl" })

    theme = RecordingStudioEmbeddable::Renderer.embed_theme_for(recording, embed: embed)

    assert_equal "serif", theme[:font_family]
    assert_equal "#ff0000", theme[:text_color]
    assert_equal "lg", theme[:radius_scale]
    assert_equal "xl", theme[:padding_scale]
  end

  def test_renderer_embed_theme_ignores_undeclared_overrides
    recording = FakeRecording.new(FakeRecordable.new(true), Time.now)
    embed = Struct.new(:appearance).new({ "text_color" => "#ff0000" })

    theme = RecordingStudioEmbeddable::Renderer.embed_theme_for(recording, embed: embed)

    assert_equal({}, theme)
  end

  def test_styling_validator_rejects_unknown_keys_and_normalizes_values
    definitions = {
      text_color: { type: :color },
      max_width: { type: :length }
    }

    result = RecordingStudioEmbeddable::Styling::ValidateOverrides.call(
      values: {
        "text_color" => "#ABC",
        "max_width" => "900px",
        "unknown_token" => "oops"
      },
      definitions: definitions
    )

    refute result.valid?
    assert_equal "#aabbcc", result.cleaned["text_color"]
    assert_equal "900px", result.cleaned["max_width"]
    assert_equal "is not an editable style option", result.errors["unknown_token"]
  end

  def test_styling_resolver_tracks_precedence_sources
    recordable = FakeThemeRecordable.new
    recording = FakeRecording.new(recordable, Time.now)
    embed = Struct.new(:appearance).new({ "padding_scale" => "xl" })

    result = RecordingStudioEmbeddable::Styling::ResolveTheme.call(recording: recording, embed: embed)

    assert_equal "#111827", result.tokens[:text_color]
    assert_equal "xl", result.tokens[:padding_scale]
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
    assert_equal "#111827", result[:defaults]["text_color"]
    assert_equal true, result[:allow_custom_styling]
  end

  def test_styling_definitions_use_recordable_declared_customizable_schema
    recording = FakeRecording.new(FakeCustomizableRecordable.new, Time.now)

    definitions = RecordingStudioEmbeddable::Styling::Definitions.call(recording: recording)

    assert_equal "Background", definitions[:background_color][:label]
    assert_equal :color, definitions[:background_color][:type]
    assert_equal "--surface-background-color", definitions[:background_color][:css_variable]

    assert_equal :enum, definitions[:max_width][:type]
    assert_equal %w[640px 960px], definitions[:max_width][:options]
    assert_equal "max-width", definitions[:max_width][:css_property]

    assert_equal :enum, definitions[:font_family][:type]
  end

  def test_recordable_defaults_service_uses_customizable_style_defaults
    recording = FakeRecording.new(FakeCustomizableRecordable.new, Time.now)

    result = RecordingStudioEmbeddable::Styling::RecordableDefaults.call(recording: recording)

    assert_equal "#fafafa", result[:defaults]["background_color"]
    assert_equal "960px", result[:defaults]["max_width"]
  end

  def test_embed_layout_helper_emits_only_declared_body_styles
    helper_host = Object.new
    helper_host.extend(RecordingStudioEmbeddable::EmbedLayoutHelper)
    helper_host.instance_variable_set(:@recording, FakeRecording.new(FakeCustomizableRecordable.new, Time.now))
    helper_host.instance_variable_set(
      :@embed_theme,
      { background_color: "#fafafa", max_width: "960px", font_family: "serif" }
    )

    style = helper_host.embed_layout_body_attributes[:style]

    assert_includes style, "--surface-background-color: #fafafa"
    assert_includes style, "font-family: ui-serif, Georgia, Cambria, Times New Roman, serif"
    refute_includes style, "max-width"
  end

  def test_resolver_uses_recordable_defaults_service_layer
    stubbed = lambda do |recording:|
      {
        recordable_type: recording.recordable.class.name,
        defaults: { "font_family" => "mono", "text_color" => "#222222" },
        allow_custom_styling: true
      }
    end

    original = RecordingStudioEmbeddable::Styling::RecordableDefaults.method(:call)
    RecordingStudioEmbeddable::Styling::RecordableDefaults.define_singleton_method(:call, stubbed)

    begin
      recording = FakeRecording.new(FakeThemeRecordable.new, Time.now)
      embed = Struct.new(:appearance).new({ "text_color" => "#ff0000" })

      result = RecordingStudioEmbeddable::Styling::ResolveTheme.call(recording: recording, embed: embed)

      assert_equal "mono", result.tokens[:font_family]
      assert_equal "#ff0000", result.tokens[:text_color]
      assert_equal "recordable", result.sources[:font_family]
      assert_equal "embed", result.sources[:text_color]
    ensure
      RecordingStudioEmbeddable::Styling::RecordableDefaults.define_singleton_method(:call, original)
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
    engine_routes = File.read(File.expand_path("../config/routes.rb", __dir__))
    page = File.read(File.expand_path("dummy/app/models/page.rb", __dir__))

    assert_includes routes, "mount RecordingStudioEmbeddable::Engine"
    assert_includes engine_routes, "get :preview"
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
    assert_includes migration, "AND trashed_at IS NULL"
    refute_includes migration, "column_exists?(:recording_studio_recordings, :trashed_at)"
  end

  def test_view_log_migration_uses_postgresql_safe_index_names
    migration = File.read(
      File.expand_path("../db/migrate/20250101000002_create_recording_studio_embeddable_view_logs.rb", __dir__)
    )

    assert_includes migration, "idx_rse_view_logs_embed_viewed_at"
    refute_includes migration, "index_recording_studio_embeddable_view_logs_on_embed_id_and_viewed_at"
  end

  def test_embeddable_view_log_uses_canonical_table_name
    assert_equal "recording_studio_embeddable_view_logs", RecordingStudioEmbeddable::EmbeddableViewLog.table_name
  end

  def test_management_application_controller_uses_core_default_layout
    source = File.read(File.expand_path("../app/controllers/recording_studio_embeddable/application_controller.rb",
                                        __dir__))

    assert_includes source, "RecordingStudio::UsesDefaultLayout"
    assert_includes source, 'layout "recording_studio/default_layout"'
    refute_includes source, 'layout "recording_studio_embeddable/application"'
  end

  def test_default_layout_head_copies_rounded_theme_onto_html
    source = File.read(File.expand_path("../app/views/recording_studio/_default_layout_head.html.erb", __dir__))

    assert_includes source, 'stylesheet_link_tag "flat_pack/application"'
    assert_includes source, 'document.documentElement.setAttribute("data-theme", "rounded")'
  end

  def test_public_embed_layout_stays_chrome_free_with_rounded_theme
    source = File.read(File.expand_path("../app/views/layouts/recording_studio_embeddable/embed.html.erb", __dir__))

    assert_includes source, '<html data-theme="rounded">'
    refute_includes source, "recording_studio/default_layout"
  end

  def test_dummy_home_uses_flatpack_dropdown_actions
    source = File.read(File.expand_path("dummy/app/views/home/index.html.erb", __dir__))

    assert_includes source, "FlatPack::Button::Dropdown::Component"
    assert_includes source, "show_chevron: false"
    assert_includes source, 'icon: "ellipsis-vertical"'
    refute_includes source, "No embed"
    refute_includes source, "app_nav"
  end

  def test_dummy_embed_cards_drop_placeholder_copy
    %w[
      dummy/app/views/pages/_embed.html.erb
      dummy/app/views/articles/embed.html.erb
      dummy/app/views/documents/show.html.erb
    ].each do |relative_path|
      source = File.read(File.expand_path(relative_path, __dir__))

      refute_includes source, "This text uses the main text color."
    end
  end

  def test_dummy_tailwind_sources_resolve_loaded_gems
    require_relative "dummy/lib/dummy/tailwind_gem_sources"

    directories = Dummy::TailwindGemSources.source_directories
    css = Dummy::TailwindGemSources.css

    assert(directories.any? { |path| path.include?("flatpack") || path.include?("flat_pack") })
    assert(directories.any? { |path| path.include?("RecordingStudio") || path.include?("recording_studio") })
    assert_includes css, "@source"
    assert_includes css, "app/components"
    assert_includes css, "app/views"
  end

  def test_dummy_tailwind_entry_imports_generated_gem_sources
    source = File.read(File.expand_path("dummy/app/assets/tailwind/application.css", __dir__))

    assert_includes source, '@import "./gem_sources.css"'
    refute_includes source, "/usr/local/bundle"
    refute_includes source, "vendor/bundle/**/flatpack"
  end

  def test_embed_code_screen_caps_form_width_and_shortens_help
    source = File.read(
      File.expand_path("../app/views/recording_studio_embeddable/management/embeds/edit.html.erb", __dir__)
    )

    assert_includes source, "FlatPack::Grid::Component.new(cols: 2)"
    assert_includes source, "FlatPack::TextArea::Component.new("
    assert_includes source, "Paste this into your page."
    refute_includes source, "Copy the code below"
    refute_includes source, "FlatPack::TextInput::Component"
    assert_includes source, 'title: "Embed"'
    assert_includes source, "subtitle: recordable_title"
    refute_includes source, "large_subtitle"
    assert_includes source, "section_nav"
  end

  def test_linking_embed_screens_drop_repeated_chrome
    %w[styling stats].each do |action|
      source = File.read(
        File.expand_path("../app/views/recording_studio_embeddable/management/embeds/#{action}.html.erb", __dir__)
      )

      refute_includes source, "section_nav"
      refute_includes source, "large_subtitle"
      refute_includes source, "Getting Started"
      assert_includes source, "subtitle: recordable_title"
    end

    settings = File.read(
      File.expand_path("../app/views/recording_studio_embeddable/management/embeds/settings.html.erb", __dir__)
    )
    styling = File.read(
      File.expand_path("../app/views/recording_studio_embeddable/management/embeds/styling.html.erb", __dir__)
    )
    stats = File.read(
      File.expand_path("../app/views/recording_studio_embeddable/management/embeds/stats.html.erb", __dir__)
    )

    refute_includes settings, "section_nav"
    assert_includes settings, 'title: "Embed settings"'
    assert_includes settings, "subtitle: recordable_title"
    refute_includes settings, "large_subtitle"
    assert_includes settings, "FlatPack::Grid::Component.new(cols: 2)"
    assert_includes settings, 'label: "Width"'
    assert_includes settings, 'label: "Height"'
    refute_includes settings, "Iframe sizing"
    refute_includes settings, "These values control the copied iframe element itself."
    refute_includes settings, "Iframe width"
    refute_includes settings, "Iframe height"

    assert_includes styling, 'title: "Styling"'
    assert_includes styling, "FlatPack::Grid::Component.new(cols: 2)"
    assert_includes styling, "FlatPack::ColorSwatch::Component"
    assert_includes styling, "FlatPack::FontSwatch::Component"
    assert_includes styling, "FlatPack::OverflowRow::Component.new(gap: :md)"
    assert_includes styling, "default_color: reset_color"
    assert_includes styling, "default_font: reset_font_css"
    assert_includes styling, 'data-controller~="flat-pack--color-swatch"'
    assert_includes styling, 'data-controller~="flat-pack--font-swatch"'
    assert_includes styling, 'id: "embed_appearance_font_family"'
    assert_includes styling, 'id="embed-styling-preview"'
    assert_includes styling, "preview_management_embed_path(@embed)"
    refute_includes styling, "FlatPack::Select::Component"
    refute_includes styling, "ChipGroup"
    refute_includes styling, "flex flex-wrap items-start gap-[var(--stack-gap-md)]"
    refute_includes styling, "overflow-x-auto"
    refute_includes styling, "data-styling-color-swatch"
    refute_includes styling, "data-color-picker-trigger-name"
    refute_includes styling, "padding_scale"
    refute_includes styling, "radius_scale"
    refute_includes styling, "Embed overrides"
    refute_includes styling, 'text: "Preview"'

    assert_includes stats, 'title: "Stats"'
    refute_includes stats, "Embed Stats"
  end

  def test_styling_actions_are_one_row_of_separate_buttons
    source = File.read(
      File.expand_path("../app/views/recording_studio_embeddable/management/embeds/styling.html.erb", __dir__)
    )

    assert_includes source, 'class="flex flex-wrap items-center gap-3"'
    assert_includes source, 'text: "Save"'
    assert_includes source, "style: :primary"
    assert_includes source, 'text: "Reset"'
    refute_includes source, 'text: "Preview"'
    refute_includes source, "ButtonGroup"
    refute_includes source, "flex-col items-start"
    refute_includes source, "styling-save-button"
  end

  def test_font_family_token_passes_through_css_stacks
    stack = "ui-serif, Georgia, serif"

    assert_equal stack, RecordingStudioEmbeddable::Styling::Tokens.resolve_font_family_css(stack)
    assert_equal stack, RecordingStudioEmbeddable::Styling::Tokens.font_swatch_css_for("serif")
    assert_equal "Sans", RecordingStudioEmbeddable::Styling::Tokens.font_swatch_label_for("sans")
    assert_equal "Serif", RecordingStudioEmbeddable::Styling::Tokens.font_swatch_label_for(stack)
  end
end
