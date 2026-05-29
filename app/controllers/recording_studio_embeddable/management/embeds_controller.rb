# frozen_string_literal: true

module RecordingStudioEmbeddable
  module Management
    class EmbedsController < RecordingStudioEmbeddable::ApplicationController
      before_action :authorize_management!
      before_action :load_embed

      def edit; end

      def update
        if @embed.update(embed_params)
          redirect_to edit_management_embed_path(@embed), notice: "Embed settings updated."
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def preview
        @recording = @embed.parent_recording
        render Renderer.resolve(@recording, @embed), layout: "recording_studio_embeddable/iframe"
      end

      private

      def authorize_management!
        authorizer = RecordingStudioEmbeddable.configuration.management_authorizer
        allowed = authorizer.respond_to?(:call) && authorizer.call(controller: self)
        head :not_found unless allowed
      rescue StandardError
        head :not_found
      end

      def load_embed
        @embed = Embed.find(params[:id])
      end

      def embed_params
        params.require(:embed).permit(
          :enabled,
          :embed_url_strategy,
          :default_embed_mode,
          :inherit_global_domains,
          :inherit_capability_domains,
          allowed_embed_modes: [],
          allowed_embedder_domains: [],
          blocked_embedder_domains: [],
          sizing: {},
          cache_settings: {},
          logging_settings: {}
        )
      end
    end
  end
end
