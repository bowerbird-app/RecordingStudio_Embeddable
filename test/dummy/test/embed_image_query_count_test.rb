# frozen_string_literal: true

require "test_helper"

class EmbedImageQueryCountTest < ActiveSupport::TestCase
  setup do
    @original_url_mode = RecordingStudioAttachable.configuration.url_mode
    @original_direct_url_host = RecordingStudioAttachable.configuration.direct_url_host
    RecordingStudioAttachable.configuration.url_mode = :direct
    RecordingStudioAttachable.configuration.direct_url_host = "cdn.example.test"

    @user = User.find_or_create_by!(email: "embed-image-queries@example.test") do |user|
      user.password = "Password"
      user.password_confirmation = "Password"
    end
    @workspace = Workspace.find_or_create_by!(name: "Embed Image Query Workspace")
    @root = RecordingStudio.create_root_recording!(@workspace, actor: @user)
    unless RecordingStudioAccessible.authorized?(actor: @user, recording: @root, role: :admin)
      result = RecordingStudioAccessible.bootstrap_owner_access!(recording: @root, actor: @user)
      raise result.error unless result.success?
    end
    @helper = Object.new.extend(RecordingStudioEmbeddable::DirectImageHelper)
  end

  teardown do
    RecordingStudioAttachable.configuration.url_mode = @original_url_mode
    RecordingStudioAttachable.configuration.direct_url_host = @original_direct_url_host
  end

  test "cover and gallery query count stays the same for 1 and 5 images" do
    one = page_with_images(1)
    five = page_with_images(5)
    @helper.embed_cover_and_gallery(one)

    one_count = sql_query_count { @helper.embed_cover_and_gallery(one) }
    five_count = sql_query_count { @helper.embed_cover_and_gallery(five) }

    assert_equal one_count, five_count, "1 image issued #{one_count} queries, 5 images issued #{five_count}"

    gallery = @helper.embed_cover_and_gallery(five)
    assert_equal RecordingStudioEmbeddable::DirectImageUrls::COVER_SIZES, gallery[:cover].sizes
    assert_includes gallery[:cover].src, "https://cdn.example.test/"
    assert_includes gallery[:cover].srcset, "480w"
    assert_includes gallery[:cover].srcset, "960w"
    assert_equal 4, gallery[:gallery].length
    assert_equal RecordingStudioEmbeddable::DirectImageUrls::DEFAULT_SIZES, gallery[:gallery].first.sizes
    assert_includes gallery[:gallery].first.srcset, "1600w"
  end

  private

  def page_with_images(image_count)
    page = Page.create!(title: "Query count #{image_count}", description: "Embed image query count.")
    recording = RecordingStudio::Recording.unscoped.create!(
      root_recording_id: @root.id,
      parent_recording_id: @root.id,
      recordable: page
    )
    path = Rails.root.join("db/seed_images/kiln-canister-hero.jpg")
    image_count.times do |index|
      image_recording = File.open(path, "rb") do |io|
        recording.import_attachment(
          io: io,
          filename: "query-count-#{image_count}-#{index}.jpg",
          content_type: "image/jpeg",
          name: "Query count #{image_count}-#{index}",
          actor: @user,
          source: "test"
        )
      end
      raise "Could not import image #{index}" if image_recording.nil?

      attachment = image_recording.recordable
      RecordingStudioAttachable::PreprocessVariantsJob.perform_now(attachment.id)
      blob = attachment.file.blob
      blob.analyze unless blob.analyzed?
    end
    recording
  end

  def sql_query_count
    count = 0
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      next if payload[:cached] || payload[:name] == "SCHEMA"
      next if payload[:sql].to_s.match?(/\A\s*(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/i)

      count += 1
    end
    ActiveRecord::Base.uncached { yield }
    count
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end
end
