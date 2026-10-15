# frozen_string_literal: true

module RecordingStudioEmbeddable
  module ManagementModalHelper
    SCREEN_ROUTES = {
      edit: :edit_management_embed_path,
      preview: :preview_management_embed_path,
      styling: :styling_management_embed_path,
      settings: :settings_management_embed_path,
      floating: :floating_management_embed_path,
      stats: :stats_management_embed_path,
      update: :management_embed_path
    }.freeze

    SCREENS_WITH_OWN_TABS = %w[edit floating].freeze

    def recording_studio_embeddable_management_modal(recording:, tab: :edit, label: nil, title: nil, style: :primary)
      embed = recording_studio_embeddable_management_embed_for(recording)
      return "".html_safe if embed.blank?

      src = recording_studio_embeddable_management_screen_path(embed, tab, modal: true)
      parts = [
        recording_studio_embeddable_management_modal_trigger(label: label, src: src, style: style)
      ]
      unless recording_studio_embeddable_management_modal_shell_rendered?
        @_recording_studio_embeddable_management_modal_shell = true
        parts << render(
          "recording_studio_embeddable/management/modal",
          title: title.presence || t(
            "recording_studio.embeddable.management.modal.title",
            default: "Embed"
          )
        )
      end
      safe_join(parts)
    end

    def recording_studio_embeddable_management_modal_request?
      return true if request.headers["Turbo-Frame"].to_s == RecordingStudioEmbeddable::MANAGEMENT_FRAME_ID
      return true if params[:variant].to_s == RecordingStudioEmbeddable::MODAL_VARIANT

      ActiveModel::Type::Boolean.new.cast(params[:modal])
    end

    def recording_studio_embeddable_management_screen_path(embed, screen, modal: nil, **params)
      use_modal = modal.nil? ? recording_studio_embeddable_management_modal_request? : modal
      params[:variant] = RecordingStudioEmbeddable::MODAL_VARIANT if use_modal
      route = SCREEN_ROUTES.fetch(screen.to_sym) do
        raise ArgumentError, "Unknown embed management tab: #{screen}"
      end
      recording_studio_embeddable_management_router.public_send(route, embed, **params)
    end

    def recording_studio_embeddable_management_variant_field
      return "".html_safe unless recording_studio_embeddable_management_modal_request?

      hidden_field_tag(:variant, RecordingStudioEmbeddable::MODAL_VARIANT)
    end

    def recording_studio_embeddable_management_form_data
      return {} unless recording_studio_embeddable_management_modal_request?

      { turbo_frame: RecordingStudioEmbeddable::MANAGEMENT_FRAME_ID }
    end

    def recording_studio_embeddable_management_tab_data
      if recording_studio_embeddable_management_modal_request?
        { turbo_frame: RecordingStudioEmbeddable::MANAGEMENT_FRAME_ID }
      else
        {}
      end
    end

    def recording_studio_embeddable_management_preview_data
      if recording_studio_embeddable_management_modal_request?
        { turbo_frame: RecordingStudioEmbeddable::MANAGEMENT_FRAME_ID }
      else
        { turbo: false }
      end
    end

    def recording_studio_embeddable_management_modal_tabs?
      recording_studio_embeddable_management_modal_request? &&
        SCREENS_WITH_OWN_TABS.exclude?(action_name)
    end

    private

    def recording_studio_embeddable_management_embed_for(recording)
      return unless recording.respond_to?(:embed)

      recording.embed
    end

    def recording_studio_embeddable_management_modal_shell_rendered?
      instance_variable_defined?(:@_recording_studio_embeddable_management_modal_shell) &&
        @_recording_studio_embeddable_management_modal_shell
    end

    def recording_studio_embeddable_management_modal_trigger(label:, src:, style:)
      text = label.presence || t("recording_studio.embeddable.management.modal.open", default: "Embed")
      render FlatPack::Button::Component.new(
        text: text,
        style: style,
        type: "button",
        data: {
          action: "click->flat-pack--modal#open",
          modal_id: RecordingStudioEmbeddable::MANAGEMENT_MODAL_ID,
          recording_studio_embeddable_management_src: src
        }
      )
    end

    def recording_studio_embeddable_management_router
      route = SCREEN_ROUTES.fetch(:edit)
      return self if respond_to?(route, true)

      recording_studio_embeddable
    end
  end
end
