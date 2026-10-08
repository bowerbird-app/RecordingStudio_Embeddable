# frozen_string_literal: true

require "test_helper"

class EmbedDirectImagesTest < ActionDispatch::IntegrationTest
  setup do
    RecordingStudioEmbeddable.configuration.public_embeds_enabled = true
    RecordingStudioEmbeddable.configuration.allow_any_domain = true
    RecordingStudioEmbeddable.configuration.require_publishable = false
    RecordingStudioEmbeddable.configuration.rate_limiting_enabled = false
    RecordingStudioAttachable.configuration.url_mode = :direct
    RecordingStudioAttachable.configuration.direct_url_host = "cdn.example.test"

    @user = User.find_or_create_by!(email: "direct-images@example.test") do |user|
      user.password = "Password"
      user.password_confirmation = "Password"
    end
    @workspace = Workspace.find_or_create_by!(name: "Direct Images Workspace")
    @root = RecordingStudio::Recording.unscoped.find_or_create_by!(
      recordable: @workspace,
      parent_recording_id: nil
    )
    unless RecordingStudioAccessible.authorized?(actor: @user, recording: @root, role: :admin)
      result = RecordingStudioAccessible.bootstrap_owner_access!(recording: @root, actor: @user)
      raise result.error unless result.success?
    end

    @page = Page.create!(title: "Direct image page", description: "Cover and gallery for embed tests.")
    @page_recording = RecordingStudio::Recording.unscoped.create!(
      root_recording_id: @root.id,
      parent_recording_id: @root.id,
      recordable: @page
    )
    @embed = @page_recording.ensure_embed!(enabled: true, allowed_embedder_domains: ["example.com"])
    unless @page_recording.currently_published?
      publish = RecordingStudioPublishable::Services::Publishables::Update.call(
        parent_recording: @page_recording,
        actor: @user,
        attributes: { slug: "direct-image-page", status: "published" }
      )
      raise publish.error unless publish.success?
    end
    import_fixture_images!
  end

  teardown do
    RecordingStudioEmbeddable.configuration.require_publishable = true
    RecordingStudioEmbeddable.configuration.rate_limiting_enabled = true
  end

  test "public embed page uses only direct_url_host image URLs" do
    get "/recording_studio_embeddable/embeds/#{@embed.token}"

    assert_response :success
    assert_includes response.body, "Direct image page"
    assert_includes response.body, "https://cdn.example.test/"
    assert_includes response.body, "srcset="
    assert_includes response.body, "sizes="
    assert_includes response.body, 'loading="lazy"'
    assert_includes response.body, 'loading="eager"'
    refute_match(%r{/rails/active_storage}, response.body)
    refute_match(%r{/recording_studio_attachable/.*/preview/}, response.body)
  end

  test "dummy cdn route serves blob bytes for direct host keys" do
    attachment = @page_recording.images(per_page: 1).first.recordable
    key = attachment.file.blob.key

    get "/dummy_cdn/#{key}"

    assert_response :success
    assert_equal "image/jpeg", response.media_type
    assert response.body.bytesize.positive?
  end

  test "cdn publish html never includes rails fallback image paths" do
    storage = RecordingStudioArtifacts.configuration.cdn_storage
    storage.clear! if storage.respond_to?(:clear!)
    RecordingStudioEmbeddable.configuration.artifacts_enabled = true
    RecordingStudioEmbeddable::Embed.where(id: @embed.id).update_all(embed_url_strategy: "cdn")
    embed = RecordingStudioEmbeddable::Embed.find(@embed.id)

    result = RecordingStudioEmbeddable::Services::PublishEmbedToCdn.call(embed: embed, synchronous: true)
    assert result.success?, result.error.to_s
    refute result.value[:deferred], result.value.inspect

    artifact_id = result.value[:artifact_id]
    stored = storage.read("recording_studio_artifacts/#{artifact_id}")
    assert stored.present?, "expected MemoryStorage object for published embed"
    html = stored[:body]

    assert_includes html, "https://cdn.example.test/"
    assert_includes html, "srcset="
    refute_match(%r{/rails/active_storage}, html)
    refute_match(%r{/recording_studio_attachable/.*/preview/}, html)
    assert RecordingStudioEmbeddable::PublishedHtmlGuard.direct_only?(html)
  ensure
    RecordingStudioEmbeddable.configuration.artifacts_enabled = false
  end

  private

  def import_fixture_images!
    dir = Rails.root.join("db/seed_images")
    %w[
      kiln-canister-hero.jpg
      kiln-canister-open.jpg
      kiln-canister-detail.jpg
    ].each do |filename|
      path = dir.join(filename)
      recording = File.open(path, "rb") do |io|
        @page_recording.import_attachment(
          io: io,
          filename: filename,
          content_type: "image/jpeg",
          name: filename,
          actor: @user,
          source: "test"
        )
      end
      RecordingStudioAttachable::PreprocessVariantsJob.perform_now(recording.recordable.id)
      blob = recording.recordable.file.blob
      blob.analyze unless blob.analyzed?
    end
  end
end
