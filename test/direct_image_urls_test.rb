# frozen_string_literal: true

require "test_helper"

class DirectImageUrlsTest < Minitest::Test
  FakeBlob = Struct.new(:key, :metadata, keyword_init: true)
  FakeFile = Struct.new(:blob, :attached) do
    def attached? = attached
  end

  class FakeAttachment
    attr_reader :file, :alt_text, :caption, :credit, :name, :original_filename
    attr_accessor :processed

    def initialize(host:, processed: %i[small med large])
      @host = host
      @processed = processed.map(&:to_sym)
      @file = FakeFile.new(FakeBlob.new(key: "original-key", metadata: { "width" => 1200, "height" => 800 }), true)
      @alt_text = "Canister"
      @caption = "Hero"
      @credit = "Studio"
      @name = "Kiln"
      @original_filename = "hero.jpg"
    end

    def original_url(mode: nil, rails_url: nil)
      raise ArgumentError, "rails_url required" if mode == :rails && rails_url.blank?

      "https://#{@host}/#{file.blob.key}"
    end

    def variant_processed?(name)
      processed.include?(name.to_sym)
    end

    def url_for_variant(name, mode: nil, rails_url: nil)
      unless variant_processed?(name)
        raise ArgumentError, "rails_url is required when a direct variant URL cannot be built" if rails_url.blank?

        return rails_url
      end

      "https://#{@host}/variant-#{name}"
    end
  end

  def setup
    @host = "cdn.example.test"
    unless defined?(RecordingStudioAttachable)
      Object.const_set(:RecordingStudioAttachable, Module.new)
    end
    unless RecordingStudioAttachable.const_defined?(:ConfigurationError)
      RecordingStudioAttachable.const_set(:ConfigurationError, Class.new(StandardError))
    end
    unless RecordingStudioAttachable.const_defined?(:DirectUrl)
      mod = Module.new do
        def self.normalize_host(host)
          host.to_s.strip.sub(%r{\Ahttps?://}i, "").delete_suffix("/")
        end
      end
      RecordingStudioAttachable.const_set(:DirectUrl, mod)
    end
    unless RecordingStudioAttachable.respond_to?(:configuration)
      config = Object.new
      config.define_singleton_method(:direct_url_host) { "cdn.example.test" }
      config.define_singleton_method(:preprocessed_variants) { %i[small med large poster] }
      config.define_singleton_method(:image_variant) do |name|
        {
          small: { resize_to_limit: [480, 480] },
          med: { resize_to_limit: [960, 960] },
          large: { resize_to_limit: [1600, 1600] },
          poster: { resize_to_limit: [1280, 720] }
        }[name.to_sym]
      end
      RecordingStudioAttachable.define_singleton_method(:configuration) { config }
    end
  end

  def test_builds_srcset_from_processed_direct_variants_only
    attachment = FakeAttachment.new(host: @host, processed: %i[small med large])
    source = RecordingStudioEmbeddable::DirectImageUrls.for_attachment(attachment)

    assert_equal "https://cdn.example.test/variant-med", source.src
    assert_includes source.srcset, "https://cdn.example.test/variant-small 480w"
    assert_includes source.srcset, "https://cdn.example.test/variant-med 960w"
    assert_includes source.srcset, "https://cdn.example.test/variant-large 1600w"
    refute_includes source.srcset, "/rails/active_storage"
    refute_includes source.srcset, "/recording_studio_attachable/"
    assert_equal 1200, source.width
    assert_equal 800, source.height
  end

  def test_omits_unprocessed_variants_instead_of_rails_fallback
    attachment = FakeAttachment.new(host: @host, processed: %i[med])
    source = RecordingStudioEmbeddable::DirectImageUrls.for_attachment(attachment)

    assert_equal "https://cdn.example.test/variant-med", source.src
    assert_equal "https://cdn.example.test/variant-med 960w", source.srcset
    refute_includes source.srcset.to_s, "preview"
    refute_includes source.src.to_s, "/rails/"
  end

  def test_falls_back_to_original_direct_url_when_no_variants_processed
    attachment = FakeAttachment.new(host: @host, processed: [])
    source = RecordingStudioEmbeddable::DirectImageUrls.for_attachment(attachment)

    assert_equal "https://cdn.example.test/original-key", source.src
    assert_nil source.srcset
  end
end
