# frozen_string_literal: true

require "test_helper"

class StoredEmbedModesTest < ActiveSupport::TestCase
  setup do
    RecordingStudioEmbeddable.reset_configuration!
  end

  teardown do
    RecordingStudioEmbeddable.reset_configuration!
  end

  test "stored iframe and oembed modes stay after the config default is iframe only" do
    embed = RecordingStudioEmbeddable::Embed.create!(
      enabled: true,
      allowed_embed_modes: %w[iframe oembed]
    )
    RecordingStudioEmbeddable.configuration.allowed_embed_modes = %i[iframe]
    reloaded = RecordingStudioEmbeddable::Embed.find(embed.id)

    assert_equal %w[iframe oembed], reloaded.allowed_embed_modes
  end
end
