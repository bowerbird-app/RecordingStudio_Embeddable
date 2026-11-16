# frozen_string_literal: true

module RecordingStudioEmbeddable
  # Builds Attachable direct-delivery URLs for embed HTML.
  #
  # Uses only public Attachable APIs: +original_url(mode: :direct)+,
  # +url_for_variant(..., mode: :direct)+, and +variant_processed?+.
  # Never returns a Rails / Active Storage fallback path — unprocessed
  # variants are omitted from +srcset+ instead of falling back.
  class DirectImageUrls # rubocop:disable Metrics/ClassLength
    VariantSource = Struct.new(
      :name,
      :url,
      :width,
      :descriptor,
      keyword_init: true
    )

    ImageSource = Struct.new(
      :attachment,
      :alt,
      :caption,
      :credit,
      :src,
      :srcset,
      :sizes,
      :width,
      :height,
      :variants,
      keyword_init: true
    )

    DEFAULT_SRCSET_VARIANTS = %i[small med large].freeze
    DEFAULT_SIZES = "(max-width: 640px) 100vw, (max-width: 1024px) 90vw, 960px"
    COVER_SIZES = "100vw"

    # Width hints from Attachable's default +resize_to_limit+ variants.
    VARIANT_WIDTHS = {
      small: 480,
      med: 960,
      large: 1600,
      xlarge: 2400,
      poster: 1280
    }.freeze

    def self.for_attachment(attachment, sizes: DEFAULT_SIZES, variant_names: nil, variant_records: nil)
      new(
        attachment,
        sizes: sizes,
        variant_names: variant_names,
        variant_records: variant_records
      ).image_source
    end

    def self.cover_for_attachment(attachment, variant_names: nil, variant_records: nil)
      for_attachment(
        attachment,
        sizes: COVER_SIZES,
        variant_names: variant_names,
        variant_records: variant_records
      )
    end

    def self.with_sizes(source, sizes)
      return if source.nil?

      ImageSource.new(**source.to_h, sizes: sizes)
    end

    def self.sources_for(recordings, sizes: DEFAULT_SIZES, variant_names: nil)
      recordings = Array(recordings)
      preload_embed_images!(recordings)
      recordings.filter_map do |recording|
        attachment = attachment_for(recording)
        next unless attachment

        for_attachment(
          attachment,
          sizes: sizes,
          variant_names: variant_names,
          variant_records: loaded_variant_records(attachment)
        )
      end
    end

    def self.preload_embed_images!(recordings)
      preloadable = recordings.select { |recording| recording.respond_to?(:association) }
      return if preloadable.empty?

      ActiveRecord::Associations::Preloader.new(records: preloadable, associations: :recordable).call

      attachments = preloadable.filter_map { |recording| attachment_for(recording) }
      return if attachments.empty?

      ActiveRecord::Associations::Preloader.new(
        records: attachments,
        associations: { file_attachment: :blob }
      ).call

      blobs = attachments.filter_map { |attachment| attached_blob(attachment) }
      return if blobs.empty?
      return unless blobs.first.class.reflect_on_association(:variant_records)

      ActiveRecord::Associations::Preloader.new(
        records: blobs,
        associations: { variant_records: { image_attachment: :blob } }
      ).call
    end
    private_class_method :preload_embed_images!

    def self.attachment_for(recording)
      return unless recording.respond_to?(:recordable)

      recordable = recording.recordable
      recordable if recordable.respond_to?(:file)
    end
    private_class_method :attachment_for

    def self.attached_blob(attachment)
      file = attachment.file
      return unless file.respond_to?(:attached?) && file.attached?

      file.blob if file.respond_to?(:blob)
    end
    private_class_method :attached_blob

    def self.loaded_variant_records(attachment)
      blob = attached_blob(attachment)
      return unless blob.respond_to?(:association)
      return unless blob.class.reflect_on_association(:variant_records)

      association = blob.association(:variant_records)
      return unless association.loaded?

      association.target
    end
    private_class_method :loaded_variant_records

    def initialize(attachment, sizes: DEFAULT_SIZES, variant_names: nil, variant_records: nil)
      @attachment = attachment
      @sizes = sizes
      @variant_names = Array(variant_names.presence || default_variant_names).map(&:to_sym)
      @variant_records = variant_records
    end

    def image_source
      return nil unless attachment_ready?

      variants = processed_variant_sources
      src = preferred_src(variants)
      return nil if src.blank? || !direct_host_url?(src)

      width, height = intrinsic_dimensions
      ImageSource.new(
        attachment: attachment,
        alt: alt_text,
        caption: attachment.try(:caption).presence,
        credit: attachment.try(:credit).presence,
        src: src,
        srcset: srcset_attribute(variants),
        sizes: sizes,
        width: width,
        height: height,
        variants: variants
      )
    end

    private

    attr_reader :attachment, :sizes, :variant_names, :variant_records

    def attachment_ready?
      attachment.present? &&
        attachment.respond_to?(:file) &&
        attachment.file.attached? &&
        attachment.respond_to?(:original_url)
    end

    def default_variant_names
      if defined?(RecordingStudioAttachable)
        names = RecordingStudioAttachable.configuration.preprocessed_variants
        return names if names.present?
      end

      DEFAULT_SRCSET_VARIANTS
    end

    def processed_variant_sources
      return variant_sources_from_records unless variant_records.nil?

      variant_names.filter_map do |name|
        next unless attachment.respond_to?(:variant_processed?) && attachment.variant_processed?(name)

        url = attachment.url_for_variant(name, mode: :direct, rails_url: nil)
        next unless direct_host_url?(url)

        width = variant_width(name)
        VariantSource.new(
          name: name,
          url: url,
          width: width,
          descriptor: "#{width}w"
        )
      rescue ArgumentError
        nil
      end
    end

    def variant_sources_from_records
      return [] unless direct_variants_available?

      by_digest = variant_records.index_by(&:variation_digest)
      variant_names.filter_map do |name|
        url = preloaded_variant_url(name, by_digest)
        next unless direct_host_url?(url)

        width = variant_width(name)
        VariantSource.new(
          name: name,
          url: url,
          width: width,
          descriptor: "#{width}w"
        )
      end
    end

    def direct_variants_available?
      file = attachment.file
      return false unless file.respond_to?(:attached?) && file.attached?
      return false if file.respond_to?(:variable?) && !file.variable?
      return false if attachment.respond_to?(:variants_allowed?) && !attachment.variants_allowed?

      true
    end

    def preloaded_variant_url(name, by_digest)
      digest = variation_digest_for(name)
      return if digest.blank?

      record = by_digest[digest]
      return if record.nil?

      key = preloaded_variant_blob_key(record)
      return if key.blank? || key == attachment.file.blob.key

      RecordingStudioAttachable::DirectUrl.build(key)
    rescue ArgumentError, RecordingStudioAttachable::ConfigurationError
      nil
    end

    def variation_digest_for(name)
      return unless attachment.respond_to?(:variant_named)

      attachment.variant_named(name)&.variation&.digest
    rescue ArgumentError
      nil
    end

    def preloaded_variant_blob_key(record)
      image_attachment = loaded_association_target(record, :image_attachment)
      return if image_attachment.nil?

      loaded_association_target(image_attachment, :blob)&.key
    end

    def loaded_association_target(record, name)
      return unless record.respond_to?(:association)

      association = record.association(name)
      return unless association.loaded?

      association.target
    end

    def preferred_src(variants)
      preferred = variants.find { |variant| variant.name == :med } ||
                  variants.find { |variant| variant.name == :large } ||
                  variants.first
      return preferred.url if preferred

      original = attachment.original_url(mode: :direct, rails_url: nil)
      original if direct_host_url?(original)
    rescue ArgumentError, RecordingStudioAttachable::ConfigurationError
      nil
    end

    def srcset_attribute(variants)
      return nil if variants.blank?

      variants.map { |variant| "#{variant.url} #{variant.descriptor}" }.join(", ")
    end

    def variant_width(name)
      configured = VARIANT_WIDTHS[name.to_sym]
      return configured if configured

      transformations = RecordingStudioAttachable.configuration.image_variant(name)
      limit = transformations&.dig(:resize_to_limit) || transformations&.dig(:resize_to_fill)
      Array(limit).first.to_i.presence || 960
    end

    def intrinsic_dimensions
      metadata = attachment.file.blob&.metadata
      width = positive_int(metadata && (metadata["width"] || metadata[:width]))
      height = positive_int(metadata && (metadata["height"] || metadata[:height]))
      return [width, height] if width && height

      [VARIANT_WIDTHS[:med], VARIANT_WIDTHS[:med]]
    end

    def alt_text
      attachment.try(:alt_text).presence ||
        attachment.try(:name).presence ||
        attachment.try(:original_filename).presence ||
        "Image"
    end

    def direct_host_url?(url)
      return false if url.blank?

      host = RecordingStudioAttachable.configuration.direct_url_host.to_s
      return false if host.blank?

      normalized = RecordingStudioAttachable::DirectUrl.normalize_host(host)
      uri = URI.parse(url.to_s)
      return false unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
      return false if uri.path.to_s.start_with?("/rails/active_storage")
      return false if uri.path.to_s.include?("/recording_studio_attachable/")

      uri.host.to_s == normalized.split("/").first.split(":").first ||
        url.to_s.start_with?("https://#{normalized}/")
    rescue URI::InvalidURIError
      false
    end

    def positive_int(value)
      number = Integer(value, exception: false)
      number if number&.positive?
    end
  end # rubocop:enable Metrics/ClassLength
end
