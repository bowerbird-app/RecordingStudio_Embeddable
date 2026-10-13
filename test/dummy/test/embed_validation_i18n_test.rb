# frozen_string_literal: true

require "test_helper"

class EmbedValidationI18nTest < ActiveSupport::TestCase
  INVALID_DOMAIN = "localhost"
  HOST_INVALID_DOMAIN = "HOST Invalid embedder domain: localhost"
  ERROR_KEY = "recording_studio.embeddable.errors.invalid_embedder_domain"
  FRESH_HOST_LOCALE = Rails.root.join("test/locales/embeddable_host_override.en.yml")

  setup do
    @load_path_before = I18n.load_path.dup
    @backend_before = I18n.backend
    @previous_locale = I18n.locale
    @previous_available_locales = I18n.available_locales
  end

  teardown do
    I18n.locale = @previous_locale
    I18n.available_locales = @previous_available_locales
    I18n.backend = @backend_before if @backend_before
    assert_equal @load_path_before, I18n.load_path,
                 "validation i18n tests must not mutate I18n.load_path"
  end

  test "english invalid domain error details match main string type" do
    embed = RecordingStudioEmbeddable::Embed.new(
      enabled: true,
      allowed_embedder_domains: [INVALID_DOMAIN]
    )

    refute embed.valid?
    assert_includes embed.errors[:base], "Invalid embedder domain: localhost"
    assert_equal [{ error: "Invalid embedder domain: localhost" }], embed.errors.details[:base]
  end

  test "french locale carries translated string as the error type" do
    I18n.available_locales = I18n.available_locales | [:fr]
    I18n.backend.store_translations(
      :fr,
      recording_studio: {
        embeddable: {
          errors: {
            invalid_embedder_domain: "Domaine d'embed invalide : %{domain}"
          }
        }
      }
    )

    embed = nil
    I18n.with_locale(:fr) do
      embed = RecordingStudioEmbeddable::Embed.new(
        enabled: true,
        allowed_embedder_domains: [INVALID_DOMAIN]
      )
      refute embed.valid?
    end

    assert_includes embed.errors.full_messages, "Domaine d'embed invalide : localhost"
    assert_equal [{ error: "Domaine d'embed invalide : localhost" }], embed.errors.details[:base]
  end

  test "host override wins for invalid domain error type" do
    snapshot = i18n_backend_translations_snapshot
    I18n.t(ERROR_KEY, domain: "x")
    I18n.backend.load_translations(FRESH_HOST_LOCALE.to_s)

    embed = RecordingStudioEmbeddable::Embed.new(
      enabled: true,
      allowed_embedder_domains: [INVALID_DOMAIN]
    )

    refute embed.valid?
    assert_includes embed.errors[:base], HOST_INVALID_DOMAIN
    assert_equal [{ error: HOST_INVALID_DOMAIN }], embed.errors.details[:base]
  ensure
    restore_i18n_backend_translations(snapshot) if snapshot
  end

  private

  def i18n_backend_translations_snapshot
    backend = I18n.backend
    backend.send(:init_translations) unless backend.initialized?
    translations =
      if backend.respond_to?(:translations)
        backend.translations
      else
        backend.instance_variable_get(:@translations)
      end
    return unless translations

    deep_plain_copy(translations)
  end

  def restore_i18n_backend_translations(snapshot)
    backend = I18n.backend
    backend.instance_variable_set(:@translations, snapshot)
    backend.instance_variable_set(:@initialized, true) if backend.instance_variable_defined?(:@initialized)
  end

  def deep_plain_copy(value)
    case value
    when Hash
      value.each_with_object({}) { |(key, nested), copy| copy[key] = deep_plain_copy(nested) }
    when Array
      value.map { |nested| deep_plain_copy(nested) }
    else
      value
    end
  end
end
