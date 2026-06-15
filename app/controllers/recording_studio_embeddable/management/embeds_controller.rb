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

      def stats
        build_stats_chart_state
      end

      def update
        form_context = params[:form_context].to_s
        apply_embed_params
        if @embed.save
          if form_context == "settings"
            redirect_to settings_management_embed_path(@embed), notice: "Embed settings updated."
          else
            redirect_to edit_management_embed_path(@embed), notice: "Embed settings updated."
          end
        elsif form_context == "settings"
          render :settings, status: :unprocessable_entity
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
        submitted = styling_appearance_params
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

        persist_embed_overrides(validation.cleaned)
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

      def styling_appearance_params
        appearance = params.fetch(:embed, {}).fetch(:appearance, {})
        return appearance.to_h unless appearance.is_a?(ActionController::Parameters)

        # Styling::ValidateOverrides is the allowlist for accepted keys/values.
        appearance.permit!.to_h
      end

      def build_stats_chart_state
        @stats_range_picker = stats_range_picker
        @stats_range = stats_range
        @stats_granularity = stats_granularity
        @stats_viewer_filter = stats_viewer_filter
        @stats_range_options = {
          "7d" => "Last 7 days",
          "30d" => "Last 30 days",
          "90d" => "Last 90 days"
        }
        @stats_granularity_options = {
          "day" => "Per day",
          "week" => "Per week",
          "month" => "Per month"
        }
        @stats_viewer_options = {
          "all" => "All views",
          "unique" => "Unique views",
          "humans" => "Humans only",
          "bots" => "Bots only"
        }

        @stats_from_date = parse_stats_date(params[:from])
        @stats_to_date = parse_stats_date(params[:to])

        @stats_custom_range = @stats_from_date.present? && @stats_to_date.present?
        if @stats_custom_range
          @stats_from_date, @stats_to_date = @stats_to_date, @stats_from_date if @stats_from_date > @stats_to_date
          @stats_from_date = @stats_to_date - 365 if (@stats_to_date - @stats_from_date).to_i > 365

          from_time = @stats_from_date.beginning_of_day
          to_time = @stats_to_date.end_of_day
        else
          from_time = stats_from_time(@stats_range)
          to_time = Time.current
        end

        relation = RecordingStudioEmbeddable::EmbeddableViewLog.where(embed: @embed)
        relation = relation.where(viewed_at: from_time..to_time)
        relation = relation.humans if @stats_viewer_filter == "humans"
        relation = relation.bots if @stats_viewer_filter == "bots"

        grouped_counts =
          if @stats_viewer_filter == "unique"
            relation
              .where.not(viewer_digest: nil)
              .pluck(:viewed_at, :viewer_digest)
              .group_by { |viewed_at, _digest| stats_bucket_key(viewed_at.in_time_zone.to_date, @stats_granularity) }
              .transform_values { |rows| rows.map { |_viewed_at, digest| digest }.uniq.size }
          else
            relation
              .pluck(:viewed_at)
              .group_by { |value| stats_bucket_key(value.in_time_zone.to_date, @stats_granularity) }
              .transform_values(&:size)
          end
        periods = stats_periods(from_time.to_date, to_time.to_date, @stats_granularity)

        @stats_chart_categories = periods.map { |period| stats_bucket_label(period, @stats_granularity) }
        @stats_chart_points = periods.map { |period| grouped_counts.fetch(period, 0) }
        @stats_chart_total = @stats_chart_points.sum
        @stats_chart_series = [{ name: @stats_viewer_options.fetch(@stats_viewer_filter), data: @stats_chart_points }]
        @stats_geo_rows = build_geo_rows(relation)
        @stats_subtitle_range =
          if @stats_custom_range
            "#{@stats_from_date.strftime('%b %-d, %Y')} to #{@stats_to_date.strftime('%b %-d, %Y')}"
          else
            @stats_range_options.fetch(@stats_range).downcase
          end
      end

      def build_geo_rows(relation)
        geo_counts = Hash.new { |hash, key| hash[key] = { views: 0, unique_digests: {}, human_views: 0, bot_views: 0 } }

        relation.pluck(:metadata, :viewer_digest, :bot).each do |metadata, viewer_digest, bot|
          country_code = metadata.is_a?(Hash) ? metadata["country"].presence : nil
          country = country_code || "Unknown"
          geo_counts[country][:views] += 1
          geo_counts[country][:unique_digests][viewer_digest] = true if viewer_digest.present?
          if bot
            geo_counts[country][:bot_views] += 1
          else
            geo_counts[country][:human_views] += 1
          end
        end

        geo_counts
          .map do |country, data|
            {
              country: country,
              views: data[:views],
              unique_views: data[:unique_digests].size,
              human_views: data[:human_views],
              bot_views: data[:bot_views]
            }
          end
          .sort_by { |row| [-row[:views], row[:country]] }
          .first(15)
      end

      def stats_range_picker
        value = params[:range].to_s
        return value if %w[7d 30d 90d custom].include?(value)

        "30d"
      end

      def stats_range
        value = stats_range_picker
        return "30d" if value == "custom"

        value
      end

      def stats_viewer_filter
        value = params[:viewer].to_s
        return value if %w[all unique humans bots].include?(value)

        "all"
      end

      def stats_granularity
        value = params[:granularity].to_s
        return value if %w[day week month].include?(value)

        "day"
      end

      def stats_periods(start_date, end_date, granularity)
        case granularity
        when "week"
          periods = []
          cursor = start_date.beginning_of_week
          while cursor <= end_date
            periods << cursor
            cursor += 7.days
          end
          periods
        when "month"
          periods = []
          cursor = start_date.beginning_of_month
          while cursor <= end_date
            periods << cursor
            cursor = cursor.next_month.beginning_of_month
          end
          periods
        else
          (start_date..end_date).to_a
        end
      end

      def stats_bucket_key(date, granularity)
        case granularity
        when "week" then date.beginning_of_week
        when "month" then date.beginning_of_month
        else date
        end
      end

      def stats_bucket_label(bucket, granularity)
        case granularity
        when "week"
          "Week of #{bucket.strftime('%b %-d')}"
        when "month"
          bucket.strftime("%b %Y")
        else
          bucket.strftime("%b %-d")
        end
      end

      def stats_from_time(range)
        case range
        when "7d" then 6.days.ago.beginning_of_day
        when "90d" then 89.days.ago.beginning_of_day
        else 29.days.ago.beginning_of_day
        end
      end

      def parse_stats_date(raw_value)
        return nil if raw_value.blank?

        Date.iso8601(raw_value.to_s)
      rescue ArgumentError
        nil
      end

      def build_styling_state
        @recording = @embed.parent_recording
        @parent_recordable = @recording&.recordable if @recording.respond_to?(:recordable)
        @recordable = @parent_recordable
        assign_recordable_instance_variable

        @styling_definitions = visible_styling_definitions
        legacy_font_keys = Styling::Tokens::FONT_STACKS.keys.map(&:downcase)
        @font_options = Services::GoogleFonts.options
                                             .map(&:to_s)
                                             .map(&:strip)
                                             .reject(&:blank?)
                                             .reject { |font| legacy_font_keys.include?(font.downcase) }
                                             .uniq
        @styling_overrides = @embed.appearance.to_h.stringify_keys
        resolved = Styling::ResolveTheme.call(recording: @recording, embed: @embed)
        @resolved_theme = resolved.values.stringify_keys
        @theme_sources = resolved.sources.stringify_keys
        @styling_editable = styling_editable?
        @styling_errors ||= {}
      end

      def visible_styling_definitions
        RecordingStudioEmbeddable::Styling::Definitions.call(recording: @recording)
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

      def normalize_domain_lines(text)
        text.to_s
            .split(/\r?\n/)
            .map { |line| normalize_domain_entry(line) }
            .reject(&:blank?)
            .uniq
      end

      def normalize_domain_entry(value)
        input = value.to_s.strip
        return "" if input.blank?

        host = begin
          parsed = URI.parse(input)
          parsed.host.presence || parsed.path.to_s
        rescue URI::InvalidURIError
          input
        end

        host.to_s.downcase.sub(%r{/.*\z}, "").strip
      rescue URI::InvalidURIError
        input
      end

      def assign_recordable_instance_variable
        return unless @parent_recordable.respond_to?(:model_name)

        instance_variable_set(:"@#{@parent_recordable.model_name.element}", @parent_recordable)
      end
    end
  end
end
