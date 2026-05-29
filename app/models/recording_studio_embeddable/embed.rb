# frozen_string_literal: true

module RecordingStudioEmbeddable
  class Embed < ApplicationRecord
    self.table_name = "recording_studio_embeddable_embeds"

    has_many :views, class_name: "RecordingStudioEmbeddable::View", dependent: :delete_all

    before_validation :ensure_token

    validates :token, presence: true, uniqueness: true
    validates :enabled, inclusion: { in: [true, false] }
    validate :domains_are_valid

    scope :enabled, -> { where(enabled: true) }

    before_validation :apply_defaults

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

      scope = RecordingStudio::Recording.where(recordable_type: self.class.name, recordable_id: id)
      scope = scope.where(trashed_at: nil) if RecordingStudioEmbeddable.recording_has_trashed_at?
      scope.first
    end

    def parent_recording
      recording&.parent_recording if recording.respond_to?(:parent_recording)
    end

    def public_path
      "/recording_studio_embeddable/embeds/#{token}"
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

    class << self
      def generate_token
        SecureRandom.urlsafe_base64(RecordingStudioEmbeddable.configuration.token_bytes).tr("-_", "Aa")[0, 32]
      end
    end
  end
end
