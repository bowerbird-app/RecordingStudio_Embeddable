# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class ManagementRecordingEmbedTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  PASSWORD = "Password"

  setup do
    @owner = create_user("owner")
    @editor = create_user("editor")
    @viewer = create_user("viewer")
    @stranger = create_user("stranger")
    Current.actor = @owner

    workspace = Workspace.create!(name: "Manage link #{SecureRandom.hex(4)}")
    @root = RecordingStudio.root_recording_for(workspace)
    grant_embed_management!(actor: @owner, recording: @root)
    grant_role!(@editor, :edit)
    grant_role!(@viewer, :view)

    @page = @root.record(Page, actor: @owner) { |page| page.title = "Managed page" }
    @document = @root.record(Document, actor: @owner) { |document| document.title = "Notes" }

    other_workspace = Workspace.create!(name: "Other link #{SecureRandom.hex(4)}")
    @other_root = RecordingStudio.root_recording_for(other_workspace)
    @other_owner = create_user("other-owner")
    Current.actor = @other_owner
    grant_embed_management!(actor: @other_owner, recording: @other_root)
    @other_page = @other_root.record(Page, actor: @other_owner) { |page| page.title = "Other page" }
    @other_embed = @other_page.ensure_embed!(actor: @other_owner, enabled: true)
    Current.actor = @owner
  end

  teardown { Current.actor = nil }

  test "route is the mounted management recording embed show action" do
    path = "/recording_studio_embeddable/management/recordings/#{@page.id}/embed"
    recognized = Rails.application.routes.recognize_path(path)

    assert_equal "recording_studio_embeddable/management/embeds", recognized[:controller]
    assert_equal "show", recognized[:action]
    assert_equal @page.id, recognized[:recording_id]
  end

  test "helper path and url use the engine mount" do
    path = helper.recording_studio_embeddable_management_path(@page, tab: :settings)
    url = helper.recording_studio_embeddable_management_url(@page, tab: :settings)
    mounted = recording_studio_embeddable.management_recording_embed_path(@page, tab: :settings)

    assert_equal "/recording_studio_embeddable/management/recordings/#{@page.id}/embed?tab=settings", path
    assert_equal mounted, path
    assert_equal recording_studio_embeddable.management_recording_embed_url(@page, tab: :settings), url
    assert_includes url, path
  end

  test "home link and modal opener use the route before an embed exists" do
    sign_in @editor
    get root_path

    path = "/recording_studio_embeddable/management/recordings/#{@page.id}/embed"
    assert_select "a[href=?][data-turbo-prefetch=?]", path, "false"
    assert_nil @page.reload.embed

    html = helper.recording_studio_embeddable_management_modal(
      recording: @page,
      tab: :styling,
      label: "Page embed"
    )

    assert_includes html, path
    assert_includes html, "tab=styling"
    assert_includes html, "variant=modal"
    assert_includes html, 'data-turbo-prefetch="false"'
    assert_includes html, "Page embed"
    assert_nil @page.reload.embed
  end

  test "find or create redirects to the embed editor and a second request is the same embed" do
    sign_in @editor

    assert_difference -> { embed_count(@page) }, 1 do
      get management_path(@page)
    end

    embed = @page.reload.embed
    assert embed
    assert_redirected_to recording_studio_embeddable.edit_management_embed_path(embed)
    follow_redirect!
    assert_response :success

    assert_no_difference -> { embed_count(@page) } do
      get management_path(@page)
    end

    assert_equal embed.id, @page.reload.embed.id
    assert_redirected_to recording_studio_embeddable.edit_management_embed_path(embed)
  end

  test "redirect keeps tab and modal or turbo frame context" do
    sign_in @editor
    get management_path(@page)
    embed = @page.reload.embed

    get management_path(@page), params: { tab: "preview", variant: "modal" }
    assert_redirected_to recording_studio_embeddable.preview_management_embed_path(embed, variant: "modal")

    get management_path(@page), params: { tab: "settings", modal: "1" }
    assert_redirected_to recording_studio_embeddable.settings_management_embed_path(
      embed,
      variant: "modal",
      modal: "1"
    )

    get management_path(@page),
        params: { tab: "stats" },
        headers: { "Turbo-Frame" => RecordingStudioEmbeddable::MANAGEMENT_FRAME_ID }
    assert_redirected_to recording_studio_embeddable.stats_management_embed_path(embed, variant: "modal")
  end

  test "prefetch requests do not create an embed" do
    sign_in @editor

    [
      { "Sec-Purpose" => "prefetch" },
      { "X-Sec-Purpose" => "prefetch" },
      { "Purpose" => "prefetch" },
      { "Sec-Purpose" => "prefetch; anonymous-client-ip" }
    ].each do |headers|
      assert_no_difference -> { embed_count(@page) }, headers.inspect do
        get management_path(@page), headers: headers
      end
      assert_response :no_content
    end

    assert_nil @page.reload.embed
  end

  test "missing non-embeddable and unauthorized recordings are 404 and do not create" do
    sign_in @editor
    assert_no_difference -> { embed_count(@document) } do
      get management_path(@document)
    end
    assert_response :not_found

    get "/recording_studio_embeddable/management/recordings/#{SecureRandom.uuid}/embed"
    assert_response :not_found

    sign_in @viewer
    assert_no_difference -> { embed_count(@page) } do
      get management_path(@page)
    end
    assert_response :not_found

    sign_in @stranger
    assert_no_difference -> { embed_count(@page) } do
      get management_path(@page), headers: { "Sec-Purpose" => "prefetch" }
    end
    assert_response :not_found
    assert_nil @page.reload.embed
  end

  test "existing management actions are 404 without edit and open with edit" do
    sign_in @editor
    get management_path(@page)
    follow_redirect!
    embed = @page.reload.embed

    get recording_studio_embeddable.edit_management_embed_path(embed)
    assert_response :success

    sign_in @viewer
    get recording_studio_embeddable.edit_management_embed_path(embed)
    assert_response :not_found

    get recording_studio_embeddable.styling_management_embed_path(embed)
    assert_response :not_found

    patch recording_studio_embeddable.management_embed_path(embed),
          params: { embed: { enabled: "1", allowed_embedder_domains_text: "example.com" } }
    assert_response :not_found

    sign_in @editor
    get recording_studio_embeddable.edit_management_embed_path(@other_embed)
    assert_response :not_found

    get management_path(@other_page)
    assert_response :not_found
    assert_equal @other_embed.id, @other_page.reload.embed.id
  end

  private

  def helper
    controller = ApplicationController.new
    controller.request = ActionDispatch::TestRequest.create
    controller.request.host = "www.example.com"
    controller.response = ActionDispatch::TestResponse.new
    controller.view_context
  end

  def management_path(recording)
    recording_studio_embeddable.management_recording_embed_path(recording)
  end

  def embed_count(recording)
    RecordingStudio::Recording.where(
      parent_recording_id: recording.id,
      recordable_type: "RecordingStudioEmbeddable::Embed",
      trashed_at: nil
    ).count
  end

  def create_user(name)
    User.create!(
      email: "#{name}-#{SecureRandom.hex(4)}@example.com",
      password: PASSWORD,
      password_confirmation: PASSWORD
    )
  end

  def grant_role!(actor, role)
    result = RecordingStudioAccessible.grant_access(
      recording: @root,
      actor: actor,
      role: role,
      manager_actor: @owner
    )
    raise result.error unless result.success?
  end
end
