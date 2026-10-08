# frozen_string_literal: true

require "test_helper"

class DomainPolicySameOriginTest < Minitest::Test
  FakeEmbed = Struct.new(:allowed_domains, :blocked_domains, :inherit_global_domains, :inherit_capability_domains) do
    def initialize(allowed_domains: [], blocked_domains: [])
      super(allowed_domains, blocked_domains, true, true)
    end
  end

  def setup
    RecordingStudioEmbeddable.reset_configuration!
    RecordingStudioEmbeddable.configuration.allow_any_domain = false
    RecordingStudioEmbeddable.configuration.require_domain_allowlist = true
  end

  def teardown
    RecordingStudioEmbeddable.reset_configuration!
  end

  def test_same_origin_referer_is_allowed_even_when_not_on_partner_allowlist
    embed = FakeEmbed.new(allowed_domains: ["partner.example"])
    policy = RecordingStudioEmbeddable::Security::DomainPolicy.new(
      embed: embed,
      referer: "http://127.0.0.1:3000/recording_studio_embeddable/management/embeds/1/edit",
      request_host: "127.0.0.1"
    )

    assert policy.allowed?
  end

  def test_cross_origin_referer_still_requires_allowlist
    embed = FakeEmbed.new(allowed_domains: ["partner.example"])
    policy = RecordingStudioEmbeddable::Security::DomainPolicy.new(
      embed: embed,
      referer: "https://evil.example/page",
      request_host: "127.0.0.1"
    )

    refute policy.allowed?
  end

  def test_blank_host_remains_allowed
    embed = FakeEmbed.new(allowed_domains: ["partner.example"])
    policy = RecordingStudioEmbeddable::Security::DomainPolicy.new(
      embed: embed,
      request_host: "127.0.0.1"
    )

    assert policy.allowed?
  end
end
