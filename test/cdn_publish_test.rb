# frozen_string_literal: true

require "test_helper"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/hash/keys"
require "active_support/core_ext/hash/deep_merge"
require "active_support/core_ext/string/inflections"
require "securerandom"

class CdnPublishTest < Minitest::Test
  FakeRecordable = Struct.new(:title) do
    def self.recording_studio_embeddable_options
      { enabled: true, renderer: "recording_studio_embeddable/embeds/default", require_publishable: false }
    end

    def self.model_name = ActiveModel::Name.new(self, nil, "FakePage")
  end

  FakeRecording = Struct.new(:recordable, :updated_at, :id) do
    def currently_published? = true
  end

  FakeArtifact = Struct.new(:id, :public_url, :object_key, :etag, keyword_init: true)

  class FakeEmbed
    attr_accessor :token, :enabled, :embed_url_strategy, :metadata, :id,
                  :allowed_embedder_domains, :blocked_embedder_domains,
                  :inherit_global_domains, :inherit_capability_domains,
                  :appearance, :sizing, :updated_at, :parent_recording

    def initialize(token:)
      @token = token
      @enabled = true
      @embed_url_strategy = "cdn"
      @metadata = {}
      @id = "embed-#{token}"
      @allowed_embedder_domains = ["partner.example"]
      @blocked_embedder_domains = []
      @inherit_global_domains = true
      @inherit_capability_domains = true
      @appearance = {}
      @sizing = {}
      @updated_at = Time.now.utc
      @published_calls = []
    end

    def enabled? = !!@enabled

    def cdn_url_strategy?
      RecordingStudioEmbeddable::Cdn.enabled? &&
        RecordingStudioEmbeddable::Cdn.strategy?(embed_url_strategy)
    end

    def allowed_domains = Array(@allowed_embedder_domains)
    def blocked_domains = Array(@blocked_embedder_domains)

    def artifact_id
      metadata.dig("artifact", "id")
    end

    def artifact_public_url
      metadata.dig("artifact", "public_url")
    end

    def artifact_public_path
      url = artifact_public_url
      return URI.parse(url).path if url.present?

      nil
    rescue URI::InvalidURIError
      nil
    end

    def mark_cdn_published!(artifact_id:, public_url:, object_key: nil, etag: nil)
      stamp = Time.now.utc.iso8601
      @metadata = (@metadata || {}).deep_dup
      @metadata["artifact"] = {
        "id" => artifact_id,
        "public_url" => public_url,
        "object_key" => object_key,
        "etag" => etag,
        "published_at" => stamp
      }.compact
      @published_calls << @metadata["artifact"]
    end

    def cdn_published?
      metadata.dig("artifact", "published_at").present?
    end

    def public_path
      return artifact_public_path if cdn_url_strategy?

      "/recording_studio_embeddable/embeds/#{token}"
    end

    def public_url(host: nil, protocol: nil)
      return artifact_public_url if cdn_url_strategy?

      path = "/recording_studio_embeddable/embeds/#{token}"
      return path if host.blank?

      "#{protocol || 'https'}://#{host}#{path}"
    end
  end

  def setup
    RecordingStudioEmbeddable.reset_configuration!
    @bodies = {}
    @publish_calls = []
    @update_calls = []
    RecordingStudioEmbeddable.configure do |config|
      config.artifacts_enabled = true
      config.embed_url_strategy = :cdn
      config.allow_any_domain = false
      config.require_domain_allowlist = true
      config.require_publishable = false
      config.public_embeds_enabled = true
    end
    stub_artifacts_api!
  end

  def teardown
    RecordingStudioEmbeddable.reset_configuration!
    restore_artifacts_api!
  end

  def test_cdn_public_url_comes_from_artifacts_never_rails_mount
    embed = FakeEmbed.new(token: "stabletoken123")
    embed.mark_cdn_published!(
      artifact_id: "11111111-1111-1111-1111-111111111111",
      public_url: "https://artifacts.example.test/recording_studio_artifacts/11111111-1111-1111-1111-111111111111"
    )
    url = embed.public_url(host: "app.example.com", protocol: "https")

    assert_equal "https://artifacts.example.test/recording_studio_artifacts/11111111-1111-1111-1111-111111111111", url
    refute_includes url, "recording_studio_embeddable"
    assert_equal "/recording_studio_artifacts/11111111-1111-1111-1111-111111111111", embed.public_path
  end

  def test_dedicated_strategy_keeps_rails_mount_path
    RecordingStudioEmbeddable.configuration.embed_url_strategy = :dedicated
    embed = FakeEmbed.new(token: "dedicatedtoken")
    embed.embed_url_strategy = "dedicated"

    assert_equal "/recording_studio_embeddable/embeds/dedicatedtoken", embed.public_path
    assert_equal "https://app.example.com/recording_studio_embeddable/embeds/dedicatedtoken",
                 embed.public_url(host: "app.example.com", protocol: "https")
  end

  def test_published_html_contains_only_direct_url_host_image_urls
    host = "cdn.example.test"
    html = <<~HTML
      <html><head></head><body>
        <img src="https://#{host}/cover-key" srcset="https://#{host}/v-small 480w, https://#{host}/v-med 960w" width="1200" height="800">
      </body></html>
    HTML
    embed = build_embed(token: "direct-imgs")
    stub_ensure_variants_success! do
      stub_document_render(html) do
        result = publish_embed(embed)
        assert result.success?, result.error.to_s
        body = @bodies[embed.artifact_id]
        assert_includes body, "https://#{host}/cover-key"
        refute_match(%r{/rails/active_storage}, body)
        refute_match(%r{/recording_studio_attachable/.*/preview/}, body)
      end
    end
  end

  def test_publish_defers_when_image_variants_are_not_yet_processed
    embed = build_embed(token: "defer-variants")
    ensure_mod = RecordingStudioEmbeddable::Services::EnsureEmbedImageVariants
    failure = RecordingStudioEmbeddable::Services::BaseService::Result.new(
      success: false,
      error: "Embed image variants are not processed yet: att-1:med"
    )

    enqueued = []
    job = Module.new
    job.define_singleton_method(:set) do |wait:|
      proxy = Object.new
      proxy.define_singleton_method(:perform_later) { |id| enqueued << { wait: wait, id: id } }
      proxy
    end
    silence_warnings { RecordingStudioEmbeddable.const_set(:PublishEmbedToCdnJob, job) }

    original = ensure_mod.method(:call)
    ensure_mod.define_singleton_method(:call) { |**_| failure }
    result = publish_embed(embed)
    assert result.success?, result.error.to_s
    assert result.value[:deferred]
    assert_match(/not processed yet/, result.value[:reason])
    assert_equal [embed.id], enqueued.map { |row| row[:id] }
    assert_empty @publish_calls
  ensure
    ensure_mod.define_singleton_method(:call, original) if ensure_mod && original
    if RecordingStudioEmbeddable.const_defined?(:PublishEmbedToCdnJob, false) &&
       RecordingStudioEmbeddable::PublishEmbedToCdnJob.is_a?(Module) &&
       !RecordingStudioEmbeddable::PublishEmbedToCdnJob.is_a?(Class)
      RecordingStudioEmbeddable.send(:remove_const, :PublishEmbedToCdnJob)
    end
  end

  def test_publish_rejects_html_with_rails_fallback_image_paths
    embed = build_embed(token: "fallback-reject")
    stub_ensure_variants_success! do
      bad = '<html><head></head><body><img src="/recording_studio_attachable/attachments/1/preview/med"></body></html>'
      stub_document_render(bad) do
        result = publish_embed(embed)
        assert result.failure?
        assert_match(/must not include Rails\/Active Storage/, result.error.to_s)
        assert_empty @publish_calls
      end
    end
  end

  def test_publish_calls_artifacts_publish_then_update_with_stable_url
    embed = build_embed(token: "overwrite-token")
    stub_document_render("<html><head></head><body>v1</body></html>") do
      first = publish_embed(embed)
      assert first.success?, first.error.to_s

      assert_equal 1, @publish_calls.size
      assert_equal 0, @update_calls.size
      first_url = first.value[:public_url]
      assert_includes first_url, "recording_studio_artifacts/"
      refute_includes first_url, "recording_studio_embeddable"
      assert embed.cdn_published?
      assert_equal first.value[:artifact_id], embed.artifact_id

      stub_document_render("<html><head></head><body>v2 other.example</body></html>") do
        second = publish_embed(embed)
        assert second.success?, second.error.to_s

        assert_equal 1, @publish_calls.size
        assert_equal 1, @update_calls.size
        assert_equal first_url, second.value[:public_url]
        assert_equal first.value[:artifact_id], second.value[:artifact_id]
        assert_includes @bodies[embed.artifact_id], "v2 other.example"
      end
    end
  end

  def test_publish_bakes_frame_ancestors_from_domain_policy
    embed = build_embed(token: "csp-token")
    stub_document_render("<html><head></head><body>csp</body></html>") do
      result = publish_embed(embed)
      assert result.success?, result.error.to_s

      assert_includes result.value[:frame_ancestors].join(" "), "partner.example"
      metadata = @publish_calls.last[:metadata]
      assert_includes Array(metadata["frame_ancestors"]).join(" "), "partner.example"
    end
  end

  def test_render_embed_document_injects_csp_marker
    html = "<html><head></head><body>hi</body></html>"
    service = RecordingStudioEmbeddable::Services::RenderEmbedDocument.allocate
    service.instance_variable_set(:@frame_ancestors, ["https://partner.example"])
    injected = service.send(:inject_frame_ancestors, html)

    assert_includes injected, "recording-studio-embeddable-csp:"
    assert_includes injected, "frame-ancestors https://partner.example"
  end

  def test_unavailable_embed_overwrites_with_none_ancestors
    embed = build_embed(token: "off-token")
    embed.enabled = false
    result = publish_embed(embed)
    assert result.success?, result.error.to_s
    assert_equal false, result.value[:available]
    assert_includes @bodies[embed.artifact_id], "Embed unavailable"
    assert_includes @bodies[embed.artifact_id], "frame-ancestors 'none'"
  end

  def test_publish_rejects_dedicated_strategy
    embed = build_embed(token: "dedicated-reject")
    embed.embed_url_strategy = "dedicated"
    result = publish_embed(embed)
    assert result.failure?
    assert_match(/CDN URL strategy/, result.error.to_s)
  end

  def test_withhold_snippet_until_published
    RecordingStudioEmbeddable.configuration.cdn_withhold_snippet_until_published = true
    recording = Object.new
    embed = FakeEmbed.new(token: "withhold-token")
    recording.define_singleton_method(:embed) { embed }
    recording.extend(RecordingStudioEmbeddable::RecordingMethods)

    assert_equal "", recording.embed_code
    public_url = "https://artifacts.example.test/recording_studio_artifacts/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
    embed.mark_cdn_published!(artifact_id: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", public_url: public_url)
    html = recording.embed_code
    assert_includes html, public_url
    refute_includes html, "recording_studio_embeddable"
  end

  def test_cdn_module_does_not_expose_spaces_helpers
    refute RecordingStudioEmbeddable::Cdn.respond_to?(:object_key)
    refute defined?(RecordingStudioEmbeddable::Cdn::SpacesClient)
    refute defined?(RecordingStudioEmbeddable::Cdn::MemoryStorage)
  end

  def test_embeddable_does_not_enqueue_artifacts_publish_job
    refute RecordingStudioEmbeddable.const_defined?(:PublishArtifactJob)
    job_source = File.read(
      File.expand_path("../app/jobs/recording_studio_embeddable/publish_embed_to_cdn_job.rb", __dir__)
    )
    refute_includes job_source, "PublishArtifactJob"
  end

  def test_artifacts_api_stub_exposes_unpublish_but_publish_path_does_not_call_it
    unpublish_calls = []
    @artifacts_module.define_singleton_method(:unpublish) do |**kwargs|
      unpublish_calls << kwargs
      RecordingStudioEmbeddable::Services::BaseService::Result.new(
        success: true,
        value: { id: kwargs[:id], destroyed: true }
      )
    end

    embed = build_embed(token: "no-unpublish")
    embed.enabled = false
    result = publish_embed(embed)
    assert result.success?, result.error.to_s
    assert_empty unpublish_calls
    assert embed.artifact_id.present?
  end

  private

  def publish_embed(embed)
    RecordingStudioEmbeddable::Services::PublishEmbedToCdn.call(embed: embed, synchronous: true)
  end

  def build_embed(token:)
    embed = FakeEmbed.new(token: token)
    recording = FakeRecording.new(FakeRecordable.new("Hello"), Time.now.utc, "rec-1")
    embed.parent_recording = recording
    embed
  end

  def stub_document_render(html)
    klass = RecordingStudioEmbeddable::Services::RenderEmbedDocument
    result = RecordingStudioEmbeddable::Services::BaseService::Result.new(success: true, value: html)
    original = klass.method(:call)
    klass.define_singleton_method(:call) { |**_| result }
    yield
  ensure
    klass.define_singleton_method(:call, original)
  end

  def stub_ensure_variants_success!
    klass = RecordingStudioEmbeddable::Services::EnsureEmbedImageVariants
    result = RecordingStudioEmbeddable::Services::BaseService::Result.new(
      success: true,
      value: { attachments: [], variants: [] }
    )
    original = klass.method(:call)
    klass.define_singleton_method(:call) { |**_| result }
    yield
  ensure
    klass.define_singleton_method(:call, original) if klass && original
  end

  def stub_artifacts_api!
    @artifacts_module = Module.new
    bodies = @bodies
    publish_calls = @publish_calls
    update_calls = @update_calls

    @artifacts_module.define_singleton_method(:publish) do |**kwargs|
      id = SecureRandom.uuid
      public_url = "https://artifacts.example.test/recording_studio_artifacts/#{id}"
      bodies[id] = kwargs[:body]
      publish_calls << kwargs
      artifact = FakeArtifact.new(
        id: id,
        public_url: public_url,
        object_key: "recording_studio_artifacts/#{id}",
        etag: "etag-1"
      )
      RecordingStudioEmbeddable::Services::BaseService::Result.new(
        success: true,
        value: { artifact: artifact, public_url: public_url, enqueued: false }
      )
    end

    @artifacts_module.define_singleton_method(:update) do |id:, **kwargs|
      public_url = "https://artifacts.example.test/recording_studio_artifacts/#{id}"
      bodies[id] = kwargs[:body]
      update_calls << kwargs.merge(id: id)
      artifact = FakeArtifact.new(
        id: id,
        public_url: public_url,
        object_key: "recording_studio_artifacts/#{id}",
        etag: "etag-2"
      )
      RecordingStudioEmbeddable::Services::BaseService::Result.new(
        success: true,
        value: { artifact: artifact, public_url: public_url, enqueued: false }
      )
    end

    @had_artifacts = Object.const_defined?(:RecordingStudioArtifacts)
    @original_artifacts = @had_artifacts ? Object.const_get(:RecordingStudioArtifacts) : nil
    silence_warnings { Object.const_set(:RecordingStudioArtifacts, @artifacts_module) }

    cdn = Module.new
    cdn.define_singleton_method(:public_base_configured?) { true }
    cdn.define_singleton_method(:object_path) { |uuid| "/recording_studio_artifacts/#{uuid}" }
    @artifacts_module.const_set(:Cdn, cdn)
  end

  def restore_artifacts_api!
    if @had_artifacts
      silence_warnings { Object.const_set(:RecordingStudioArtifacts, @original_artifacts) }
    elsif Object.const_defined?(:RecordingStudioArtifacts)
      Object.send(:remove_const, :RecordingStudioArtifacts)
    end
  end

  def silence_warnings
    old = $VERBOSE
    $VERBOSE = nil
    yield
  ensure
    $VERBOSE = old
  end
end
