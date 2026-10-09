# frozen_string_literal: true

# Loads optional local R2 / CDN settings into ENV for development only.
# Never logs values. CI and test leave ENV unset and keep dummy fallbacks.
#
# Precedence per key: existing ENV > .env.development.local > config/local_r2.yml
module DummyLocalR2
  ARTIFACT_CDN_ENV = {
    "subdomain" => "ARTIFACT_CDN_SUBDOMAIN",
    "domain" => "ARTIFACT_CDN_DOMAIN",
    "path_prefix" => "ARTIFACT_CDN_PATH_PREFIX",
    "public_base_url" => "ARTIFACT_CDN_PUBLIC_BASE_URL",
    "r2_account_id" => "ARTIFACT_CDN_R2_ACCOUNT_ID",
    "r2_access_key_id" => "ARTIFACT_CDN_R2_ACCESS_KEY_ID",
    "r2_secret_access_key" => "ARTIFACT_CDN_R2_SECRET_ACCESS_KEY",
    "r2_bucket" => "ARTIFACT_CDN_R2_BUCKET",
    "r2_endpoint" => "ARTIFACT_CDN_R2_ENDPOINT",
    "r2_region" => "ARTIFACT_CDN_R2_REGION",
    "cloudflare_zone_id" => "ARTIFACT_CDN_CLOUDFLARE_ZONE_ID",
    "cloudflare_api_token" => "ARTIFACT_CDN_CLOUDFLARE_API_TOKEN"
  }.freeze

  R2_ENV = {
    "access_key_id" => "R2_ACCESS_KEY_ID",
    "secret_access_key" => "R2_SECRET_ACCESS_KEY",
    "endpoint" => "R2_ENDPOINT",
    "bucket" => "R2_BUCKET",
    "region" => "R2_REGION"
  }.freeze

  module_function

  def load!
    return unless Rails.env.development?

    apply_dotenv_file(Rails.root.join(".env.development.local"))
    apply_yaml_file(Rails.root.join("config/local_r2.yml"))
    mirror_r2_env_aliases!
  end

  def apply_dotenv_file(path)
    return unless path.file?

    path.each_line do |line|
      line = line.strip
      next if line.empty? || line.start_with?("#")

      key, _, value = line.partition("=")
      key = key.to_s.strip
      next if key.empty?
      next if ENV[key].to_s.strip.present?

      ENV[key] = value.to_s.strip.delete_prefix('"').delete_suffix('"').delete_prefix("'").delete_suffix("'")
    end
  end

  def apply_yaml_file(path)
    return unless path.file?

    data = YAML.safe_load(path.read, aliases: false) || {}
    return unless data.is_a?(Hash)

    set_env("ATTACHABLE_DIRECT_URL_HOST", data["direct_url_host"])

    artifact_cdn = data["artifact_cdn"]
    if artifact_cdn.is_a?(Hash)
      artifact_cdn.each do |key, value|
        env_name = ARTIFACT_CDN_ENV[key.to_s]
        set_env(env_name, value) if env_name
      end
    end

    r2 = data["r2"]
    return unless r2.is_a?(Hash)

    r2.each do |key, value|
      env_name = R2_ENV[key.to_s]
      set_env(env_name, value) if env_name
    end
  end

  # featured_in Active Storage uses :r2 credential keys; Artifacts uses ARTIFACT_CDN_R2_*.
  # When only one side is set locally, mirror into the other ENV names if unset.
  def mirror_r2_env_aliases!
    pairs = [
      %w[R2_ACCESS_KEY_ID ARTIFACT_CDN_R2_ACCESS_KEY_ID],
      %w[R2_SECRET_ACCESS_KEY ARTIFACT_CDN_R2_SECRET_ACCESS_KEY],
      %w[R2_ENDPOINT ARTIFACT_CDN_R2_ENDPOINT],
      %w[R2_BUCKET ARTIFACT_CDN_R2_BUCKET],
      %w[R2_REGION ARTIFACT_CDN_R2_REGION]
    ]
    pairs.each do |a, b|
      set_env(b, ENV[a]) if ENV[a].to_s.strip.present?
      set_env(a, ENV[b]) if ENV[b].to_s.strip.present?
    end
  end

  def set_env(name, value)
    return if name.blank?
    return if ENV[name].to_s.strip.present?

    text = value.to_s.strip
    return if text.empty?

    ENV[name] = text
  end

  def r2_active_storage_configured?
    ENV["R2_ACCESS_KEY_ID"].to_s.present? &&
      ENV["R2_SECRET_ACCESS_KEY"].to_s.present? &&
      ENV["R2_ENDPOINT"].to_s.present? &&
      ENV["R2_BUCKET"].to_s.present?
  end

  # Active Storage service + hosts are set in environments/*.rb before
  # initializers. Re-apply here once local ENV / yaml has been loaded.
  def apply_development_runtime!
    return unless Rails.env.development?

    if r2_active_storage_configured?
      Rails.application.config.active_storage.service = :r2
    end

    host = ENV["ATTACHABLE_DIRECT_URL_HOST"].to_s.strip
    return if host.blank?

    hostname = host.sub(%r{\Ahttps?://}i, "").split("/").first.split(":").first
    return if hostname.blank?

    Rails.application.config.hosts << hostname
  end
end

DummyLocalR2.load!
DummyLocalR2.apply_development_runtime!
