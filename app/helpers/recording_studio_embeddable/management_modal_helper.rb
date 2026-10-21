# frozen_string_literal: true

module RecordingStudioEmbeddable
  module ManagementTabHelper
    TAB_FOR_ACTION = {
      "edit" => :edit,
      "preview" => :preview,
      "styling" => :styling,
      "update_styling" => :styling,
      "settings" => :settings,
      "floating" => :floating,
      "update_floating" => :floating,
      "stats" => :stats
    }.freeze

    def recording_studio_embeddable_management_tab_active?(screen)
      recording_studio_embeddable_management_current_tab == screen.to_sym
    end

    def recording_studio_embeddable_management_tab_aria(screen, disabled: false)
      aria = {}
      aria[:disabled] = true if disabled
      aria[:current] = "page" if recording_studio_embeddable_management_current_tab == screen.to_sym
      aria
    end

    def recording_studio_embeddable_management_current_tab
      return :settings if action_name == "update" && params[:form_context].to_s == "settings"
      return :edit if action_name == "update"

      TAB_FOR_ACTION[action_name]
    end
  end

  module ManagementPathHelper
    def recording_studio_embeddable_management_path(recording, tab: nil, **)
      recording_studio_embeddable_management_mounted_route(
        :management_recording_embed_path,
        recording,
        tab: tab,
        **
      )
    end

    def recording_studio_embeddable_management_url(recording, tab: nil, **)
      recording_studio_embeddable_management_mounted_route(
        :management_recording_embed_url,
        recording,
        tab: tab,
        **
      )
    end

    private

    def recording_studio_embeddable_management_mounted_route(route_name, recording, tab: nil, **options)
      options = options.dup
      options[:tab] = tab if tab.present?
      recording_studio_embeddable_management_router_for(route_name).public_send(route_name, recording, **options)
    end

    def recording_studio_embeddable_management_router_for(route_name)
      return self if respond_to?(route_name, true)

      recording_studio_embeddable
    end
  end

  module ManagementModalHelper
    include ManagementTabHelper
    include ManagementPathHelper

    SCREEN_ROUTES = {
      edit: :edit_management_embed_path,
      preview: :preview_management_embed_path,
      styling: :styling_management_embed_path,
      settings: :settings_management_embed_path,
      floating: :floating_management_embed_path,
      stats: :stats_management_embed_path,
      update: :management_embed_path
    }.freeze

    def recording_studio_embeddable_management_modal(recording:, tab: :edit, label: nil, style: :primary)
      src = recording_studio_embeddable_management_path(
        recording,
        tab: tab,
        variant: RecordingStudioEmbeddable::MODAL_VARIANT
      )
      parts = [
        recording_studio_embeddable_management_modal_trigger(label: label, src: src, style: style)
      ]
      unless recording_studio_embeddable_management_modal_shell_rendered?
        @_recording_studio_embeddable_management_modal_shell = true
        parts << render("recording_studio_embeddable/management/modal")
      end
      safe_join(parts)
    end

    def recording_studio_embeddable_management_modal_request?
      return true if request.headers["Turbo-Frame"].to_s == RecordingStudioEmbeddable::MANAGEMENT_FRAME_ID
      return true if params[:variant].to_s == RecordingStudioEmbeddable::MODAL_VARIANT

      ActiveModel::Type::Boolean.new.cast(params[:modal])
    end

    def recording_studio_embeddable_management_screen_path(embed, screen, modal: nil, **params)
      use_modal = if modal.nil?
                    recording_studio_embeddable_management_modal_request?
                  else
                    recording_studio_embeddable_management_modal_request? ||
                      ActiveModel::Type::Boolean.new.cast(modal)
                  end
      params[:variant] = RecordingStudioEmbeddable::MODAL_VARIANT if use_modal
      params[:modal] = modal if recording_studio_embeddable_management_query_modal?(modal)
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

    def recording_studio_embeddable_management_embed_document_path(embed)
      recording_studio_embeddable_management_router.public_send(
        SCREEN_ROUTES.fetch(:preview),
        embed,
        document: 1
      )
    end

    private

    def recording_studio_embeddable_management_query_modal?(modal)
      return false if modal.nil? || modal == true || modal == false

      modal.present?
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
          recording_studio_embeddable_management_src: src,
          turbo_prefetch: "false"
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
