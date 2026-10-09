# frozen_string_literal: true

# Safe digs into Rails credentials for dummy development R2 / CDN / Attachable.
# Real values live in config/credentials/development.yml.enc (committed) decrypted
# by gitignored config/credentials/development.key. Never logs values.
# When the key / file is absent (CI, test, cold clones), every dig returns nil
# and callers fall back to dummy stand-ins (cdn.example.test, MemoryStorage).
module DummyDevCredentials
  PLACEHOLDER = "dev_placeholder"

  module_function

  def dig(*path)
    return if path.empty?
    return unless credentials_readable?

    value = Rails.application.credentials.dig(*path)
    text = value.is_a?(String) ? value.strip : value
    return if text.blank?
    return if text == PLACEHOLDER

    text
  rescue ActiveSupport::EncryptedConfiguration::MissingKeyError,
         ActiveSupport::EncryptedFile::MissingKeyError,
         ArgumentError,
         Errno::ENOENT
    nil
  end

  def credentials_readable?
    return false unless defined?(Rails) && Rails.application.respond_to?(:credentials)

    # Touch credentials once; MissingKeyError means no key for this env.
    Rails.application.credentials.secret_key_base
    true
  rescue ActiveSupport::EncryptedConfiguration::MissingKeyError,
         ActiveSupport::EncryptedFile::MissingKeyError,
         ArgumentError,
         Errno::ENOENT
    false
  end

  # featured_in Active Storage shape: credentials dig(:r2, …)
  def r2_active_storage_configured?
    dig(:r2, :access_key_id).present? &&
      dig(:r2, :secret_access_key).present? &&
      dig(:r2, :endpoint).present? &&
      dig(:r2, :bucket).present?
  end

  def apply_development_runtime!
    return unless Rails.env.development?
    return unless r2_active_storage_configured?

    Rails.application.config.active_storage.service = :r2

    host = dig(:recording_studio_attachable, :direct_url_host).to_s
    return if host.blank?

    hostname = host.sub(%r{\Ahttps?://}i, "").split("/").first.split(":").first
    Rails.application.config.hosts << hostname if hostname.present?
  end
end
