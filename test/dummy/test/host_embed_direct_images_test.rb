# frozen_string_literal: true

require "test_helper"

class HostEmbedDirectImagesTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    RecordingStudioAttachable.configuration.url_mode = :direct
    RecordingStudioAttachable.configuration.direct_url_host = "cdn.example.test"

    @user = User.find_or_create_by!(email: "host-embed@example.test") do |user|
      user.password = "Password"
      user.password_confirmation = "Password"
    end
    sign_in @user

    @workspace = Workspace.find_or_create_by!(name: "Host Embed Workspace")
    @root = RecordingStudio::Recording.unscoped.find_or_create_by!(
      recordable: @workspace,
      parent_recording_id: nil
    )
    unless RecordingStudioAccessible.authorized?(actor: @user, recording: @root, role: :admin)
      result = RecordingStudioAccessible.bootstrap_owner_access!(recording: @root, actor: @user)
      raise result.error unless result.success?
    end

    @page = Page.create!(title: "Host embed page", description: "Host route cover + gallery.")
    @page_recording = RecordingStudio::Recording.unscoped.create!(
      root_recording_id: @root.id,
      parent_recording_id: @root.id,
      recordable: @page
    )
    File.open(Rails.root.join("db/seed_images/kiln-canister-hero.jpg"), "rb") do |io|
      @page_recording.import_attachment(
        io: io,
        filename: "kiln-canister-hero.jpg",
        content_type: "image/jpeg",
        name: "Kiln canister",
        actor: @user,
        source: "press_kit"
      )
    end
    File.open(Rails.root.join("db/seed_images/kiln-canister-open.jpg"), "rb") do |io|
      @page_recording.import_attachment(
        io: io,
        filename: "kiln-canister-open.jpg",
        content_type: "image/jpeg",
        name: "Kiln canister, open",
        actor: @user,
        source: "press_kit"
      )
    end
    @page_recording.images(per_page: 10).each do |image_recording|
      RecordingStudioAttachable::PreprocessVariantsJob.perform_now(image_recording.recordable.id)
    end
  end

  test "host pages embed action renders Attachable direct images" do
    get page_embed_path(@page)

    assert_response :success
    assert_includes response.body, "Host embed page"
    assert_includes response.body, "https://cdn.example.test/"
    assert_includes response.body, "srcset="
    refute_match(%r{/rails/active_storage}, response.body)
  end
end
