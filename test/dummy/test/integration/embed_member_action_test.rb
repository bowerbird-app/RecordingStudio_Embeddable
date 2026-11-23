# frozen_string_literal: true

require "test_helper"

class EmbedMemberActionTest < ActionDispatch::IntegrationTest
  TEST_PASSWORD = "EmbedProofPassword!2026"

  def test_get_embed_actions_path_returns_schema_v1
    page_recording, token = provision_view_client_and_page_embed!
    view_log_count = RecordingStudioEmbeddable::EmbeddableViewLog.count

    get "/recording_studio_api/api/v1/pages/#{page_recording.id}/actions/embed",
        headers: { "Authorization" => "Bearer #{token}" }

    assert_response :ok
    assert_schema_v1(JSON.parse(response.body))
    assert_equal view_log_count, RecordingStudioEmbeddable::EmbeddableViewLog.count
  end

  def test_get_embed_short_alias_returns_schema_v1
    page_recording, token = provision_view_client_and_page_embed!

    get "/recording_studio_api/api/v1/pages/#{page_recording.id}/embed",
        headers: { "Authorization" => "Bearer #{token}" }

    assert_response :ok
    assert_schema_v1(JSON.parse(response.body))
  end

  def test_get_embed_without_bearer_token_is_unauthorized
    page_recording, = provision_view_client_and_page_embed!

    get "/recording_studio_api/api/v1/pages/#{page_recording.id}/actions/embed"

    assert_response :unauthorized
  end

  def test_get_embed_out_of_scope_page_is_not_found
    _page_recording, token = provision_view_client_and_page_embed!
    other_page = provision_foreign_page_embed!

    get "/recording_studio_api/api/v1/pages/#{other_page.id}/actions/embed",
        headers: { "Authorization" => "Bearer #{token}" }

    assert_response :not_found
  end

  def test_soft_registered_embed_handler_is_gem_owned
    action = RecordingStudioApi.capability_action(:embed)

    assert action
    assert_equal RecordingStudioEmbeddable::Api::EmbedRecording, action.handler
  end

  def test_embed_action_openapi_copy_describes_the_payload_without_access_roles
    action = RecordingStudioApi.capability_action(:embed)
    openapi = action.openapi
    responses = openapi.fetch(:responses)
    description = openapi.fetch(:description)

    assert_equal RecordingStudioEmbeddable::Api::ACTION_SUMMARY, openapi.fetch(:summary)
    assert_equal RecordingStudioEmbeddable::Api::ACTION_DESCRIPTION, description
    refute_includes description, "Press Kit"
    RecordingStudioEmbeddable::Api::ACTION_RESPONSE_DESCRIPTIONS.each do |status, text|
      response = responses[status] || responses[status.to_s] || responses[status.to_sym]
      assert response, "missing #{status} response in #{responses.keys.inspect}"
      assert_equal text, response.fetch(:description)
    end

    blob = [
      openapi.fetch(:summary),
      description,
      *responses.values.map { |entry| entry.fetch(:description) }
    ].join(" ").downcase
    assert_match(/\bedit access\b/, blob)
    %w[role admin authorized accessible].each do |word|
      refute_match(/\b#{Regexp.escape(word)}\b/, blob)
    end
    refute_includes blob, ":view"
    refute_includes blob, ":edit"
  end

  def test_view_only_caller_is_forbidden
    page_recording, token = provision_view_only_client_and_page!

    get "/recording_studio_api/api/v1/pages/#{page_recording.id}/actions/embed",
        headers: { "Authorization" => "Bearer #{token}" }

    assert_response :forbidden
    assert_nil page_recording.reload.embed
  end

  def test_edit_caller_creates_one_embed_and_reuses_it
    page_recording, token = provision_edit_client_without_embed!

    assert_nil page_recording.embed

    get "/recording_studio_api/api/v1/pages/#{page_recording.id}/actions/embed",
        headers: { "Authorization" => "Bearer #{token}" }

    assert_response :ok
    assert_schema_v1(JSON.parse(response.body))
    first_embed = page_recording.reload.embed
    assert first_embed
    refute first_embed.enabled?
    assert_equal 1, embed_count(page_recording)

    get "/recording_studio_api/api/v1/pages/#{page_recording.id}/actions/embed",
        headers: { "Authorization" => "Bearer #{token}" }

    assert_response :ok
    assert_schema_v1(JSON.parse(response.body))
    assert_equal first_embed.id, page_recording.reload.embed.id
    assert_equal 1, embed_count(page_recording)
  end

  def test_iframe_embed_route_still_mounted
    recognized = Rails.application.routes.recognize_path(
      "/recording_studio_embeddable/embeds/example-token"
    )

    assert_equal "recording_studio_embeddable/embeds", recognized[:controller]
    assert_equal "show", recognized[:action]
  end

  private

  def assert_schema_v1(body)
    assert_equal 1, body.fetch("schema_version")
    assert body.fetch("html").is_a?(String)
    assert body.fetch("configuration").key?("theme")
    assert body.fetch("configuration").key?("sizing")
    assert_equal "0.3.0", body.fetch("sdk").fetch("minimum_version")
  end

  def provision_edit_client_without_embed!
    user = create_user
    Current.actor = user
    workspace = Workspace.create!(name: "Embed create #{SecureRandom.hex(4)}")
    root_recording = RecordingStudio.create_root_recording!(workspace, actor: user)
    access_recording = bootstrap_admin!(root_recording: root_recording, actor: user)
    page_recording = record_page!(root_recording: root_recording, title: "Embed create page")
    token = issue_client_token!(access_recording: access_recording, name: "Embed create client")

    [ page_recording, token ]
  end

  def provision_view_only_client_and_page!
    owner = create_user
    Current.actor = owner
    workspace = Workspace.create!(name: "Embed view-only #{SecureRandom.hex(4)}")
    root_recording = RecordingStudio.create_root_recording!(workspace, actor: owner)
    bootstrap_admin!(root_recording: root_recording, actor: owner)
    page_recording = record_page!(root_recording: root_recording, title: "Embed view-only page")
    token = issue_client_token!(
      access_point_recording: root_recording,
      manager_actor: owner,
      role: :view,
      name: "Embed view-only client"
    )

    [ page_recording, token ]
  end

  def provision_view_client_and_page_embed!
    user = create_user
    Current.actor = user
    workspace = Workspace.create!(name: "Embed proof #{SecureRandom.hex(4)}")
    root_recording = RecordingStudio.create_root_recording!(workspace, actor: user)
    access_recording = bootstrap_admin!(root_recording: root_recording, actor: user)
    page_recording = record_page!(root_recording: root_recording, title: "Embed proof page")
    page_recording.ensure_embed!(enabled: true, actor: user)
    token = issue_client_token!(access_recording: access_recording, name: "Embed proof client")

    [ page_recording, token ]
  end

  def provision_foreign_page_embed!
    user = create_user(email: "foreign-#{SecureRandom.hex(4)}@example.com")
    Current.actor = user
    workspace = Workspace.create!(name: "Foreign #{SecureRandom.hex(4)}")
    root_recording = RecordingStudio.create_root_recording!(workspace, actor: user)
    bootstrap_admin!(root_recording: root_recording, actor: user)
    page_recording = record_page!(root_recording: root_recording, title: "Foreign page")
    page_recording.ensure_embed!(enabled: true, actor: user)
    page_recording
  end

  def create_user(email: "embed-#{SecureRandom.hex(4)}@example.com")
    User.create!(email: email, password: TEST_PASSWORD, password_confirmation: TEST_PASSWORD)
  end

  def bootstrap_admin!(root_recording:, actor:)
    result = RecordingStudioAccessible.bootstrap_owner_access!(
      recording: root_recording,
      actor: actor
    )
    raise result.error unless result.success?

    result.value
  end

  def record_page!(root_recording:, title:)
    root_recording.record(Page, actor: Current.actor) do |page|
      page.title = title
    end
  end

  def embed_count(recording)
    RecordingStudio::Recording.where(
      parent_recording_id: recording.id,
      recordable_type: "RecordingStudioEmbeddable::Embed",
      trashed_at: nil
    ).count
  end

  def issue_client_token!(name:, access_recording: nil, access_point_recording: nil, manager_actor: nil, role: nil)
    provision_args = { name: name }
    provision_args[:access_recording] = access_recording if access_recording
    provision_args[:access_point_recording] = access_point_recording if access_point_recording
    provision_args[:manager_actor] = manager_actor if manager_actor
    provision_args[:role] = role if role
    provision = RecordingStudioApi::Services::ProvisionApiClient.call(**provision_args)
    raise provision.error unless provision.success?

    token = RecordingStudioApi::Services::IssueOauthAccessToken.call(
      grant_type: "client_credentials",
      client_id: provision.value.fetch(:credential).oauth_client_id,
      client_secret: provision.value.fetch(:token)
    )
    raise token.error unless token.success?

    token.value.fetch(:access_token)
  end
end
