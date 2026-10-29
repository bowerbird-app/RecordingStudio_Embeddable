# frozen_string_literal: true

require "test_helper"

class FloatingConfigTest < Minitest::Test
  def setup
    RecordingStudioEmbeddable.reset_configuration!
  end

  def test_capability_opt_in_carries_floating_popup
    capability = RecordingStudio::Capabilities::Embeddable.to(
      floating: true,
      floating_popup: { controller: "widget_popups", action: :show }
    )

    assert_equal true, capability.options[:floating]
    assert_equal "widget_popups", capability.options[:floating_popup][:controller]
    assert_equal :show, capability.options[:floating_popup][:action]
  end

  def test_types_without_floating_are_not_capable
    assert_equal false, capability_for(floating: nil).enabled?
    assert_equal true, capability_for(floating: true, controller: "widget_popups", action: :show).enabled?
    assert_equal "widget_popups", capability_for(floating: true, controller: "widget_popups", action: :show).controller
  end

  def test_non_capable_recordings_drop_floating_attributes
    recording = recording_with(floating: false)

    assert_equal false, recording.floating_capable?
    assert_equal(
      { enabled: true },
      recording.send(:sanitize_floating_attributes,
                     { enabled: true, floating_enabled: true, floating: { "position" => "bottom-left" } })
    )
  end

  def test_capable_recordings_keep_floating_attributes
    recording = recording_with(floating: true)

    assert_equal true, recording.floating_capable?
    sanitized = recording.send(:sanitize_floating_attributes, { floating_enabled: true })
    assert_equal true, sanitized[:floating_enabled]
  end

  def test_schema_stores_position_only
    result = RecordingStudioEmbeddable::Floating::Schema.validate({})
    assert_predicate result, :valid?
    assert_equal({ "position" => "bottom-right" }, result.settings)

    left = RecordingStudioEmbeddable::Floating::Schema.validate("position" => "bottom-left")
    assert_predicate left, :valid?
    assert_equal "bottom-left", left.settings["position"]
    refute left.settings.key?("edge_spacing")

    rejected = RecordingStudioEmbeddable::Floating::Schema.validate(
      "position" => "top-left",
      "popup_url" => "https://evil.example/widget",
      "edge_spacing" => 16,
      "popup_width" => 320,
      "icon_url" => "https://images.example.com/launcher.png",
      "sandbox" => "allow-scripts allow-popups",
      "allow" => "clipboard-write"
    )
    refute_predicate rejected, :valid?
    assert_includes rejected.errors.join(" "), "unknown"
    assert_includes rejected.errors.join(" "), "position"
  end

  def test_host_settings_use_gem_defaults_then_capability_options
    RecordingStudioEmbeddable.configuration.floating_defaults = {
      "edge_spacing" => 12,
      "popup_width" => 300,
      "popup_height" => 400,
      "icon_url" => nil
    }
    plain = recording_with(floating: true)
    resolved = RecordingStudioEmbeddable::Floating::HostSettings.for(plain)
    assert_equal 12, resolved["edge_spacing"]
    assert_equal 300, resolved["popup_width"]
    assert_equal 400, resolved["popup_height"]
    assert_nil resolved["icon_url"]

    RecordingStudioEmbeddable.configuration.floating_icon_hosts = ["images.example.com"]
    overridden = recording_with(
      floating: true,
      floating_options: {
        edge_spacing: "24",
        popup_width: 400,
        popup_height: 900,
        icon_url: "https://images.example.com/launcher.png"
      }
    )
    host = RecordingStudioEmbeddable::Floating::HostSettings.for(overridden)
    assert_equal 24, host["edge_spacing"]
    assert_equal 400, host["popup_width"]
    assert_equal 400, host["popup_height"]
    assert_equal "https://images.example.com/launcher.png", host["icon_url"]
  end

  def test_preview_frame_height_fits_the_host_popup
    plain = recording_with(floating: true)
    assert_equal 560 + 56 + 12 + (20 * 2) + 16,
                 RecordingStudioEmbeddable::Floating::HostSettings.preview_frame_height(plain)

    custom = recording_with(
      floating: true,
      floating_options: { popup_height: 640, edge_spacing: 24 }
    )
    assert_equal 772, RecordingStudioEmbeddable::Floating::HostSettings.preview_frame_height(custom)
  end

  def test_host_settings_label_uses_defaults_then_the_type
    plain = RecordingStudioEmbeddable::Floating::HostSettings.for(recording_with(floating: true))
    assert_equal "Floating button", plain["label"]

    RecordingStudioEmbeddable.configuration.floating_defaults = { label: "Help bubble" }
    from_config = RecordingStudioEmbeddable::Floating::HostSettings.for(recording_with(floating: true))
    assert_equal "Help bubble", from_config["label"]

    custom = recording_with(floating: true, floating_options: { label: "  Chat button  " })
    assert_equal "Chat button", RecordingStudioEmbeddable::Floating::HostSettings.for(custom)["label"]

    blank = recording_with(floating: true, floating_options: { label: "   " })
    assert_equal "Help bubble", RecordingStudioEmbeddable::Floating::HostSettings.for(blank)["label"]

    too_long = recording_with(floating: true, floating_options: { label: "x" * 41 })
    assert_equal "Help bubble", RecordingStudioEmbeddable::Floating::HostSettings.for(too_long)["label"]
  end

  def test_host_settings_drop_a_disallowed_icon
    RecordingStudioEmbeddable.configuration.floating_defaults = {
      "icon_url" => "javascript:alert(1)"
    }
    host = RecordingStudioEmbeddable::Floating::HostSettings.for(
      recording_with(floating: true, floating_options: { icon_url: "https://cdn.evil.example/icon.png" })
    )

    assert_nil host["icon_url"]
    assert_equal 20, host["edge_spacing"]
  end

  def test_icon_url_rejects_scripts_and_unlisted_hosts
    assert RecordingStudioEmbeddable::Floating::IconUrl.allowed?("", recording: nil)
    assert RecordingStudioEmbeddable::Floating::IconUrl.allowed?(nil, recording: nil)
    refute RecordingStudioEmbeddable::Floating::IconUrl.allowed?("javascript:alert(1)", recording: nil)
    refute RecordingStudioEmbeddable::Floating::IconUrl.allowed?("https://cdn.evil.example/icon.png", recording: nil)
    refute RecordingStudioEmbeddable::Floating::IconUrl.allowed?("data:image/png;base64,aaaa", recording: nil)

    attachment = Struct.new(:url) do
      def original_url(mode:)
        mode == :direct ? url : nil
      end
    end.new("https://cdn.example.test/attachments/icon.png")
    recording = Object.new
    recording.define_singleton_method(:images) { [attachment] }

    assert RecordingStudioEmbeddable::Floating::IconUrl.allowed?(attachment.url, recording: recording)
    refute RecordingStudioEmbeddable::Floating::IconUrl.allowed?("https://cdn.example.test/attachments/other.png",
                                                                 recording: recording)
  end

  def test_colors_come_from_accent_tokens_only
    colors = RecordingStudioEmbeddable::Floating::Colors.from_tokens(
      accent_color: "#2563eb",
      accent_text_color: "expression(alert(1))"
    )

    assert_equal "#2563eb", colors["background"]
    assert_equal "#ffffff", colors["foreground"]
  end

  def test_origin_echoes_exact_http_origin_and_rejects_wildcards
    origin = RecordingStudioEmbeddable::Floating::Origin

    assert_nil origin.echoable(nil)
    assert_nil origin.echoable("")
    assert_nil origin.echoable("*")
    assert_nil origin.echoable("null")
    assert_nil origin.echoable("https://partner.example.com/")
    assert_equal "https://partner.example.com", origin.echoable("https://partner.example.com")
    assert_equal "http://partner.example.test:9292", origin.echoable("http://partner.example.test:9292")
  end

  def test_migration_adds_floating_columns
    migration = File.read(
      File.expand_path("../db/migrate/20261013120000_add_floating_to_recording_studio_embeddable_embeds.rb", __dir__)
    )

    assert_includes migration, "floating_enabled"
    assert_includes migration, "t.jsonb :floating"
    refute_includes migration, "popup_url"

    strip = File.read(
      File.expand_path("../db/migrate/20261013140000_strip_host_settings_from_embed_floating.rb", __dir__)
    )
    %w[edge_spacing popup_width popup_height icon_url].each do |key|
      assert_includes strip, key
    end
  end

  def test_document_pipeline_ignores_floating
    root = File.expand_path("../lib/recording_studio_embeddable", __dir__)
    %w[render_payload.rb html_sanitizer.rb services/publish_embed_to_cdn.rb].each do |relative|
      source = File.read(File.join(root, relative))
      refute_includes source, "floating"
    end
  end

  def test_page_and_article_do_not_opt_into_floating
    page = File.read(File.expand_path("dummy/app/models/page.rb", __dir__))
    article = File.read(File.expand_path("dummy/app/models/article.rb", __dir__))

    refute_includes page, "floating:"
    refute_includes article, "floating:"
  end

  private

  def capability_for(floating:, controller: nil, action: nil)
    options = { enabled: true }
    options[:floating] = floating unless floating.nil?
    options[:floating_popup] = { controller: controller, action: action } if controller
    recording = Struct.new(:recordable).new(recordable_with(options))
    RecordingStudioEmbeddable::Floating::Capability.for(recording)
  end

  def recording_with(floating:, floating_options: nil)
    options = { enabled: true }
    options[:floating] = true if floating
    options[:floating_options] = floating_options if floating_options
    recording = Object.new
    recording.extend(RecordingStudioEmbeddable::RecordingMethods)
    recordable = recordable_with(options)
    recording.define_singleton_method(:recordable) { recordable }
    recording
  end

  def recordable_with(options)
    klass = Class.new do
      class << self
        attr_accessor :options_for_test
      end

      define_singleton_method(:recording_studio_embeddable_options) { options_for_test }
    end
    klass.options_for_test = options
    klass.new
  end
end
