# frozen_string_literal: true

require "test_helper"

# CDN/published HTML is persisted lib output. Layout <title>, rich-body fallbacks,
# and Gallery chrome stay English literals (as on main) so locale and host English
# overrides cannot change the published document.
class CdnPublishLocaleImmunityTest < ActiveSupport::TestCase
  HOST_TITLE = "HOST Embedded recording"
  FR_TITLE = "Enregistrement intégré"
  FR_GALLERY = "Galerie"
  FR_GALLERY_SUBTITLE = "Plus de photos de cette page"
  FR_NO_DESCRIPTION = "Aucune description fournie."
  FR_EMBEDDED_PAGE = "Page intégrée"

  setup do
    @storage = RecordingStudioArtifacts.configuration.cdn_storage
    @storage.clear! if @storage.respond_to?(:clear!)
    RecordingStudioArtifacts.configuration.cdn_public_base_url = "https://artifacts.example.test"
    RecordingStudioEmbeddable.configuration.artifacts_enabled = true
    RecordingStudioEmbeddable.configuration.require_publishable = false
    RecordingStudioEmbeddable.configuration.allow_any_domain = true

    @previous_locale = I18n.locale
    @previous_available_locales = I18n.available_locales
    @backend_before = I18n.backend
    @load_path_before = I18n.load_path.dup

    Rails.application.load_seed
    @page = Page.find_by!(title: "Getting Started")
    @page_recording = RecordingStudio::Recording.unscoped.find_by!(recordable: @page)
    @embed = @page_recording.ensure_embed!(enabled: true, allowed_embedder_domains: ["example.com"])
    RecordingStudioEmbeddable::Embed.where(id: @embed.id).update_all(
      embed_url_strategy: "cdn",
      enabled: true
    )
    @embed = RecordingStudioEmbeddable::Embed.find(@embed.id)
  end

  teardown do
    I18n.locale = @previous_locale
    I18n.available_locales = @previous_available_locales
    I18n.backend = @backend_before if @backend_before
    assert_equal @load_path_before, I18n.load_path,
                 "CDN locale immunity tests must not mutate I18n.load_path"
    RecordingStudioEmbeddable.configuration.artifacts_enabled = false
    RecordingStudioEmbeddable.configuration.require_publishable = true
  end

  test "cdn publish html matches main english under fr and host english overrides" do
    baseline = publish_html!(@embed)

    assert_includes baseline, "<title>Embedded recording</title>"
    assert_includes baseline, "Gallery"
    assert_includes baseline, "More shots from this page"
    assert_includes baseline, "Getting Started"

    I18n.available_locales = I18n.available_locales | [:fr]
    I18n.backend.store_translations(
      :en,
      recording_studio: {
        embeddable: {
          common: { embedded_recording: HOST_TITLE },
          public: {
            gallery: "HOST Gallery",
            gallery_subtitle: "HOST More shots from this page",
            no_description: "HOST No description provided.",
            embedded_page: "HOST Embedded page"
          }
        }
      }
    )
    I18n.backend.store_translations(
      :fr,
      recording_studio: {
        embeddable: {
          common: { embedded_recording: FR_TITLE },
          public: {
            gallery: FR_GALLERY,
            gallery_subtitle: FR_GALLERY_SUBTITLE,
            no_description: FR_NO_DESCRIPTION,
            embedded_page: FR_EMBEDDED_PAGE
          }
        }
      }
    )

    I18n.with_locale(:fr) do
      assert_equal FR_TITLE, I18n.t("recording_studio.embeddable.common.embedded_recording")
      assert_equal HOST_TITLE, I18n.t("recording_studio.embeddable.common.embedded_recording", locale: :en)

      html = publish_html!(RecordingStudioEmbeddable::Embed.find(@embed.id))
      assert_equal baseline, html
      assert_includes html, "<title>Embedded recording</title>"
      assert_includes html, "Gallery"
      assert_includes html, "More shots from this page"
      refute_includes html, FR_TITLE
      refute_includes html, HOST_TITLE
      refute_includes html, FR_GALLERY
      refute_includes html, "HOST Gallery"
    end
  end

  private

  def publish_html!(embed)
    result = RecordingStudioEmbeddable::Services::PublishEmbedToCdn.call(
      embed: embed,
      synchronous: true
    )
    assert result.success?, result.error.to_s
    assert result.value[:available]
    artifact_id = result.value[:artifact_id]
    body = @storage.read("recording_studio_artifacts/#{artifact_id}")[:body]
    assert body.present?
    body
  end
end
