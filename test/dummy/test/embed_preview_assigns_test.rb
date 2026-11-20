# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class EmbedPreviewAssignsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  MARKERS = %w[
    data-parent-recording
    data-recording
    data-recordable
    data-parent-recordable
    data-page
    data-embed
    data-option-keys
    data-theme
  ].freeze

  setup do
    @user = User.find_or_create_by!(email: "preview-assigns@example.test") do |record|
      record.password = "Password"
      record.password_confirmation = "Password"
    end
    sign_in @user
    Current.actor = @user

    @allow_any_domain = RecordingStudioEmbeddable.configuration.allow_any_domain
    @rate_limiting = RecordingStudioEmbeddable.configuration.rate_limiting_enabled
    RecordingStudioEmbeddable.configuration.allow_any_domain = true
    RecordingStudioEmbeddable.configuration.rate_limiting_enabled = false

    workspace = Workspace.create!(name: "Preview assigns #{SecureRandom.hex(4)}")
    root = RecordingStudio.create_root_recording!(workspace, actor: @user)
    grant_embed_management!(actor: @user, recording: root)
    @page_recording = root.record(Page, actor: @user) { |page| page.title = "Parent recording page" }
    @embed = @page_recording.ensure_embed!(
      actor: @user,
      enabled: true,
      allowed_embedder_domains: ["example.com"]
    )
    publish = RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: @page_recording,
      actor: @user,
      attributes: { slug: "parent-recording-#{SecureRandom.hex(4)}", status: "published" }
    )
    raise publish.error unless publish.success?

    @original_options = Page.recording_studio_embeddable_options
    Page.recording_studio_embeddable_options = @original_options.merge(
      renderer: "pages/parent_recording_probe"
    )
  end

  teardown do
    Page.recording_studio_embeddable_options = @original_options if @original_options
    RecordingStudioEmbeddable.configuration.allow_any_domain = @allow_any_domain
    RecordingStudioEmbeddable.configuration.rate_limiting_enabled = @rate_limiting
    Current.actor = nil
  end

  test "management preview document renders a host template that reads parent_recording" do
    get recording_studio_embeddable.preview_management_embed_path(@embed, document: 1)

    assert_response :success
    assert_includes response.body, "Parent recording page"
    markers = assign_markers(response.body)
    assert_equal @page_recording.id, markers["data-parent-recording"]
    assert_equal @page_recording.recordable.id, markers["data-page"]
    assert_equal "present", markers["data-theme"]
    assert_includes markers["data-option-keys"].split(","), "renderer"
  end

  test "preview, public, cdn, and browser payload expose the same template variables" do
    get "/recording_studio_embeddable/embeds/#{@embed.token}"
    assert_response :success
    public_markers = assign_markers(response.body)

    get recording_studio_embeddable.preview_management_embed_path(@embed, document: 1)
    assert_response :success
    assert_equal public_markers, assign_markers(response.body)

    document = RecordingStudioEmbeddable::Services::RenderEmbedDocument.call(
      recording: @page_recording,
      embed: @embed
    )
    assert document.success?, document.error.to_s
    assert_equal public_markers, assign_markers(document.value!)

    payload = RecordingStudioEmbeddable::RenderPayload.call(
      recording: @page_recording,
      embed: @embed
    )
    assert payload.success?, payload.error.to_s
    assert_equal public_markers, assign_markers(payload.value!.html)
  end

  test "floating preview does not render the host embed template" do
    get recording_studio_embeddable.floating_preview_management_embed_path(@embed)

    assert_response :not_found
    refute_includes response.body, "embed-assigns"
  end

  private

  def assign_markers(body)
    node = Nokogiri::HTML(body).at_css("#embed-assigns")
    assert node, "expected the host renderer to render #embed-assigns"
    MARKERS.index_with { |name| node[name].to_s }
  end
end
