# frozen_string_literal: true

require "test_helper"

class LogsRegistrationTest < Minitest::Test
  def setup
    RecordingStudioEmbeddable.reset_configuration!
  end

  def teardown
    RecordingStudioEmbeddable.reset_configuration!
  end

  def test_logs_summaries_default_off
    assert_equal false, RecordingStudioEmbeddable.configuration.logs_summaries_enabled
    assert_equal false, RecordingStudioEmbeddable::LogsRegistration.summaries_enabled?
  end

  def test_gemspec_pins_recording_studio_logs_like_api
    gemspec = File.read(File.expand_path("../recording_studio_embeddable.gemspec", __dir__))

    assert_includes gemspec, 'spec.add_dependency "recording_studio_logs", ">= 0.4.1", "< 0.6"'
  end

  def test_register_keeps_unpartitioned_table_and_omits_actor_ip_request_fields
    RecordingStudioEmbeddable::LogsRegistration.register!
    log = RecordingStudioLogs.registry.log_for(RecordingStudioEmbeddable::LogsRegistration::SOURCE_MODEL)

    assert_equal :viewed_at, log.timestamp_column
    assert_nil log.partition_interval
    assert_equal :root_recording_id, log.root_column
    assert_equal RecordingStudioEmbeddable.configuration.prune_views_after, log.retention

    forbidden = RecordingStudioEmbeddable::LogsRegistration::FORBIDDEN_AGGREGATABLE
    aggregatable = log.contract.instance_variable_get(:@columns).keys
    forbidden.each do |column|
      refute_includes aggregatable, column
    end

    aggregation = RecordingStudioEmbeddable::LogsRegistration.embed_views_definition
    assert_equal RecordingStudioEmbeddable::LogsRegistration::EMBED_VIEWS, aggregation.name
    assert_equal %i[root_recording_id embed_id parent_recording_id status], aggregation.group_by
  end

  def test_view_log_cutover_migration_keeps_existing_table
    migration = File.read(
      File.expand_path(
        "../db/migrate/20261021000001_add_root_and_arrival_to_recording_studio_embeddable_view_logs.rb",
        __dir__
      )
    )

    refute_includes migration, "drop_table"
    refute_includes migration, "PARTITION BY"
    assert_includes migration, "root_recording_id"
    assert_includes migration, "arrived_at"
  end
end
