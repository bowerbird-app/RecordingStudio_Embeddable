# frozen_string_literal: true

class ArtifactsHomesController < ApplicationController
  def show
    configuration = RecordingStudioArtifacts.configuration
    @artifacts_enabled = RecordingStudioEmbeddable.configuration.artifacts_enabled
    @embed_url_strategy = RecordingStudioEmbeddable.configuration.embed_url_strategy
    @public_base_url = RecordingStudioArtifacts::Cdn.public_base_url
    @path_prefix = RecordingStudioArtifacts::Cdn.path_prefix
    @example_public_url = RecordingStudioArtifacts::Cdn.public_url("11111111-2222-3333-4444-555555555555")
    @storage = configuration.cdn_storage
    @using_memory_storage = @storage.is_a?(RecordingStudioArtifacts::Cdn::MemoryStorage)
    @artifact_count = RecordingStudioArtifacts::Artifact.count
  end
end
