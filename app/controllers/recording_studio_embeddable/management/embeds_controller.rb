# frozen_string_literal: true

module RecordingStudioEmbeddable
  module Management
    class EmbedsController < RecordingStudioEmbeddable::ApplicationController
      before_action :authorize_management!
      before_action :load_embed

      def edit; end

      def update
        apply_embed_params
        if @embed.save
          redirect_to edit_management_embed_path(@embed), notice: "Embed settings updated."
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def preview
        @recording = @embed.parent_recording
        @parent_recordable = @recording&.recordable if @recording.respond_to?(:recordable)
        @recordable = @parent_recordable
        assign_recordable_instance_variable
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

      def apply_embed_params
        permitted = embed_params.to_h.symbolize_keys

        if permitted.key?(:allowed_embedder_domains_text)
          permitted[:allowed_embedder_domains] = normalize_domain_lines(permitted.delete(:allowed_embedder_domains_text))
        end

        if permitted.key?(:blocked_embedder_domains_text)
          permitted[:blocked_embedder_domains] = normalize_domain_lines(permitted.delete(:blocked_embedder_domains_text))
        end

        scalar_embed_param_names.each do |name|
          @embed.public_send("#{name}=", permitted[name]) if permitted.key?(name)
        end
        json_embed_param_names.each do |name|
          @embed.public_send("#{name}=", permitted[name]) if permitted.key?(name)
        end
      end

      def scalar_embed_param_names
        %i[
          enabled
          embed_url_strategy
          default_embed_mode
          inherit_global_domains
          inherit_capability_domains
        ]
      end

      def json_embed_param_names
        %i[
          allowed_embed_modes
          allowed_embedder_domains
          blocked_embedder_domains
          sizing
          cache_settings
          logging_settings
        ]
      end

      def embed_params
        params.require(:embed).permit(
          :enabled,
          :allowed_embedder_domains_text,
          :blocked_embedder_domains_text,
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

      def normalize_domain_lines(text)
        text.to_s
          .split(/\r?\n/)
          .map(&:strip)
          .reject(&:blank?)
          .uniq
      end

      def assign_recordable_instance_variable
        return unless @parent_recordable.respond_to?(:model_name)

        instance_variable_set(:"@#{@parent_recordable.model_name.element}", @parent_recordable)
      end
    end
  end
end
