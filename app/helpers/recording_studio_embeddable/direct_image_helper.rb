# frozen_string_literal: true

module RecordingStudioEmbeddable
  module DirectImageHelper
    # Renders an +<img>+ that uses Attachable direct URLs only (srcset/sizes,
    # explicit width/height, lazy-load except cover).
    def embed_direct_image_tag(image_source, cover: false, **html_options)
      return "".html_safe if image_source.blank? || image_source.src.blank?

      tag.img(**embed_direct_image_attributes(image_source, cover: cover, **html_options))
    end

    def embed_direct_image_attributes(image_source, cover: false, **html_options)
      css_class = [
        html_options.delete(:class),
        cover ? "embed-cover-image" : "embed-gallery-image"
      ].compact.join(" ").presence
      {
        src: image_source.src,
        alt: image_source.alt,
        width: image_source.width,
        height: image_source.height,
        loading: cover ? "eager" : "lazy",
        decoding: "async",
        class: css_class,
        srcset: image_source.srcset.presence,
        sizes: image_source.sizes.presence
      }.merge(html_options).compact
    end

    def embed_image_sources_for(recording)
      return [] unless recording.respond_to?(:images)

      DirectImageUrls.sources_for(recording.images(per_page: 100))
    end

    def embed_cover_and_gallery(recording)
      sources = embed_image_sources_for(recording)
      {
        cover: DirectImageUrls.with_sizes(sources.first, DirectImageUrls::COVER_SIZES),
        gallery: sources.drop(1)
      }
    end
  end
end
