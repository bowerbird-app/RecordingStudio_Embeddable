# frozen_string_literal: true

module RecordingStudioEmbeddable
  module Management
    class EmbedsController < RecordingStudioEmbeddable::ApplicationController
      before_action :authorize_management!
      before_action :load_embed

      def edit; end

      def styling
        build_styling_state
      end

      def settings; end

      def stats; end

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
        @embed_theme = Renderer.embed_theme_for(@recording, embed: @embed)
        render Renderer.resolve(@recording, @embed),
               layout: Renderer.layout_for(@recording, @embed)
      end

      def update_styling
        build_styling_state
        submitted = params.fetch(:embed, {}).fetch(:appearance, {})
        validation_definitions = @styling_definitions.deep_dup
        if validation_definitions[:font_family]
          validation_definitions[:font_family][:options] = @font_options + Styling::Tokens::FONT_STACKS.keys
        end
        validation = Styling::ValidateOverrides.call(values: submitted, definitions: validation_definitions)
        unless validation.valid?
          @styling_errors = validation.errors
          render :styling, status: :unprocessable_entity
          return
        end

        scope = params[:styling_scope].to_s
        if scope == "recordable"
          persist_recordable_defaults(validation.cleaned)
        else
          persist_embed_overrides(validation.cleaned)
        end
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
        enabled_param = params.dig(:embed, :enabled)
        permitted[:enabled] = if enabled_param.nil?
                                false
                              else
                                ActiveModel::Type::Boolean.new.cast(enabled_param)
                              end

        if permitted.key?(:allowed_embedder_domains_text)
          permitted[:allowed_embedder_domains] =
            normalize_domain_lines(permitted.delete(:allowed_embedder_domains_text))
        end

        if permitted.key?(:blocked_embedder_domains_text)
          permitted[:blocked_embedder_domains] =
            normalize_domain_lines(permitted.delete(:blocked_embedder_domains_text))
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

      def build_styling_state
        @recording = @embed.parent_recording
        @parent_recordable = @recording&.recordable if @recording.respond_to?(:recordable)
        @recordable = @parent_recordable
        assign_recordable_instance_variable

        recordable_defaults = Styling::RecordableDefaults.call(recording: @recording)

        @styling_definitions = RecordingStudioEmbeddable.configuration.styling_tokens
        legacy_font_keys = Styling::Tokens::FONT_STACKS.keys.map(&:downcase)
        @font_options = Services::GoogleFonts.options
          .map(&:to_s)
          .map(&:strip)
          .reject(&:blank?)
          .reject { |font| legacy_font_keys.include?(font.downcase) }
          .uniq
        @styling_overrides = @embed.appearance.to_h.stringify_keys
        @recordable_defaults = recordable_defaults[:defaults].stringify_keys
        @recordable_type = recordable_defaults[:recordable_type]
        @recordable_allow_custom_styling = recordable_defaults[:allow_custom_styling]
        resolved = Styling::ResolveTheme.call(recording: @recording, embed: @embed)
        @resolved_theme = resolved.values.stringify_keys
        @theme_sources = resolved.sources.stringify_keys
        @styling_editable = styling_editable?
        @styling_errors ||= {}
      end

      def styling_editable?
        global = RecordingStudioEmbeddable.configuration.allow_custom_styling
        per_recordable = Styling::RecordableDefaults.call(recording: @recording)[:allow_custom_styling]
        ActiveModel::Type::Boolean.new.cast(global) && ActiveModel::Type::Boolean.new.cast(per_recordable)
      end

      def persist_embed_overrides(cleaned_values)
        unless @styling_editable
          redirect_to styling_management_embed_path(@embed), alert: "Custom styling is disabled for this embed."
          return
        end

        @embed.appearance = merge_styling_hash(@embed.appearance.to_h.stringify_keys, cleaned_values)

        if @embed.save
          redirect_to styling_management_embed_path(@embed), notice: "Embed styling updated."
        else
          @styling_errors = @embed.errors.to_hash
          render :styling, status: :unprocessable_entity
        end
      end

      def persist_recordable_defaults(cleaned_values)
        profile = find_or_build_styling_profile
        unless profile
          redirect_to styling_management_embed_path(@embed), alert: "Cannot save recordable defaults without a recordable type."
          return
        end

        profile.defaults = merge_styling_hash(profile.defaults.to_h.stringify_keys, cleaned_values)
        profile.allow_custom_styling = ActiveModel::Type::Boolean.new.cast(params[:recordable_allow_custom_styling])
        profile.version = profile.version.to_i + 1

        if profile.save
          redirect_to styling_management_embed_path(@embed), notice: "Recordable styling defaults updated."
        else
          @styling_errors = profile.errors.to_hash
          render :styling, status: :unprocessable_entity
        end
      end

      def merge_styling_hash(existing_values, incoming_values)
        merged = existing_values.stringify_keys
        incoming_values.each do |key, value|
          if value.nil?
            merged.delete(key.to_s)
          else
            merged[key.to_s] = value
          end
        end
        merged
      end

      def find_or_build_styling_profile
        return unless @recordable_type.present?
        return unless defined?(RecordingStudioEmbeddable::StylingProfile)
        return nil unless RecordingStudioEmbeddable::StylingProfile.table_exists?

        RecordingStudioEmbeddable::StylingProfile.find_or_initialize_by(recordable_type: @recordable_type)
      rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
        nil
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
