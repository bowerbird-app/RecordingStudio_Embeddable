# frozen_string_literal: true

module RecordingStudioEmbeddable
  class Embed < ApplicationRecord
    self.table_name = "recording_studio_embeddable_embeds"

    if respond_to?(:recording_studio_recordable)
      recording_studio_recordable(
        label: "Embed",
        plural_label: "Embeds",
        root: false
      )
    end

    has_many :embeddable_view_logs,
             class_name: "RecordingStudioEmbeddable::EmbeddableViewLog",
             dependent: :delete_all,
             inverse_of: :embed
    has_many :views,
             class_name: "RecordingStudioEmbeddable::EmbeddableViewLog",
             inverse_of: :embed

    before_validation :ensure_token

    validates :token, presence: true, uniqueness: true
    validates :enabled, inclusion: { in: [true, false] }
    validate :domains_are_valid

    scope :enabled, -> { where(enabled: true) }

    before_validation :apply_defaults
    after_commit :enqueue_cdn_publish_if_needed, on: %i[create update]

    def allowed_domains
      Array(self[:allowed_embedder_domains]).compact_blank
    end

    def allowed_embedder_domains=(value)
      self[:allowed_embedder_domains] = normalize_domain_list(value)
    end

    def blocked_domains
      Array(self[:blocked_embedder_domains]).compact_blank
    end

    def blocked_embedder_domains=(value)
      self[:blocked_embedder_domains] = normalize_domain_list(value)
    end

    def recording
      return unless defined?(RecordingStudio::Recording)

      RecordingStudio::Recording.where(
        recordable_type: self.class.name,
        recordable_id: id,
        trashed_at: nil
      ).first
    end

    def parent_recording
      recording&.parent_recording if recording.respond_to?(:parent_recording)
    end

    def url_strategy
      (try(:embed_url_strategy).presence || RecordingStudioEmbeddable.configuration.embed_url_strategy).to_s
    end

    def cdn_url_strategy?
      Cdn.strategy?(url_strategy)
    end

    # Partner-facing path. CDN strategy returns the Artifacts path (never the Rails mount).
    def public_path
      return artifact_public_path if cdn_url_strategy?

      dedicated_public_path
    end

    def dedicated_public_path
      "/recording_studio_embeddable/embeds/#{token}"
    end

    # Partner-facing absolute URL. CDN strategy returns the Artifacts public URL only.
    def public_url(host: nil, protocol: nil)
      return artifact_public_url if cdn_url_strategy?

      path = dedicated_public_path
      return path if host.blank?

      scheme = protocol || "https"
      "#{scheme}://#{host}#{path}"
    end

    def artifact_id
      value = artifact_metadata["id"] || artifact_metadata[:id]
      value.presence
    end

    def artifact_public_url
      (
        artifact_metadata["public_url"] ||
        artifact_metadata[:public_url] ||
        cdn_metadata["public_url"] ||
        cdn_metadata[:public_url]
      ).presence
    end

    def artifact_public_path
      url = artifact_public_url
      return URI.parse(url).path if url.present?

      id = artifact_id
      return unless id.present? && defined?(RecordingStudioArtifacts::Cdn)

      RecordingStudioArtifacts::Cdn.object_path(id)
    rescue URI::InvalidURIError
      nil
    end

    def cdn_published?
      artifact_metadata["published_at"].present? || cdn_metadata["published_at"].present?
    end

    def mark_cdn_published!(artifact_id:, public_url:, object_key: nil, etag: nil)
      stamp = Time.now.utc.iso8601
      next_metadata = (metadata || {}).deep_dup
      next_metadata["artifact"] = (next_metadata["artifact"] || {}).merge(
        "id" => artifact_id,
        "public_url" => public_url,
        "object_key" => object_key,
        "etag" => etag,
        "published_at" => stamp
      ).compact
      # Keep a thin cdn mirror for older readers; Artifacts is the source of truth.
      next_metadata["cdn"] = (next_metadata["cdn"] || {}).merge(
        "published_at" => stamp,
        "public_url" => public_url,
        "object_key" => object_key,
        "etag" => etag,
        "artifact_id" => artifact_id
      ).compact
      # Recordables are often readonly; update_all avoids revise and after_commit re-publish loops.
      self.class.where(id: id).update_all(metadata: next_metadata, updated_at: Time.now.utc)
      self.metadata = next_metadata
    end

    def enqueue_cdn_publish!
      return unless cdn_url_strategy?
      return unless Cdn.artifacts_available?

      PublishEmbedToCdnJob.perform_later(id)
    end

    def default_embed_mode
      (self[:default_embed_mode].presence || RecordingStudioEmbeddable.configuration.default_embed_mode).to_s
    end

    def allowed_embed_modes
      modes = self[:allowed_embed_modes].presence || RecordingStudioEmbeddable.configuration.allowed_embed_modes
      Array(modes).map(&:to_s)
    end

    def cache_settings
      self[:cache_settings] || {}
    end

    def logging_settings
      self[:logging_settings] || {}
    end

    def sizing
      (self[:sizing].presence || RecordingStudioEmbeddable.configuration.default_sizing).with_indifferent_access
    end

    def appearance
      (self[:appearance] || {}).with_indifferent_access
    end

    def appearance=(value)
      self[:appearance] = (value || {}).to_h
    end

    private

    def ensure_token
      self.token = self.class.generate_token if token.blank?
    end

    def apply_defaults
      self.enabled = false if enabled.nil?
      if has_attribute?(:embed_url_strategy)
        self.embed_url_strategy ||= RecordingStudioEmbeddable.configuration.embed_url_strategy.to_s
      end
      if has_attribute?(:default_embed_mode)
        self.default_embed_mode ||= RecordingStudioEmbeddable.configuration.default_embed_mode.to_s
      end
      self.allowed_embed_modes = RecordingStudioEmbeddable.configuration.allowed_embed_modes if
        has_attribute?(:allowed_embed_modes) && self[:allowed_embed_modes].blank?
      if has_attribute?(:sizing) && self[:sizing].blank?
        self.sizing = RecordingStudioEmbeddable.configuration.default_sizing
      end
      self.cache_settings ||= {} if has_attribute?(:cache_settings)
      self.logging_settings ||= {} if has_attribute?(:logging_settings)
      self.metadata ||= {} if has_attribute?(:metadata)
    end

    def domains_are_valid
      (allowed_domains + blocked_domains).each do |domain|
        next if Security::DomainPolicy.valid_domain?(domain)

        errors.add(:base, "Invalid embedder domain: #{domain}")
      end
    end

    def normalize_domain_list(value)
      Array(value).flat_map { |entry| entry.to_s.split(/[\s,]+/) }.map(&:strip).compact_blank.uniq
    end

    def artifact_metadata
      raw = metadata.is_a?(Hash) ? metadata : {}
      (raw["artifact"] || raw[:artifact] || {}).stringify_keys
    end

    def cdn_metadata
      raw = metadata.is_a?(Hash) ? metadata : {}
      (raw["cdn"] || raw[:cdn] || {}).stringify_keys
    end

    def enqueue_cdn_publish_if_needed
      return unless cdn_url_strategy?

      enqueue_cdn_publish!
    end

    class << self
      def generate_token
        SecureRandom.urlsafe_base64(RecordingStudioEmbeddable.configuration.token_bytes).tr("-_", "Aa")[0, 32]
      end
    end
  end
end
