# frozen_string_literal: true

require "test_helper"

class LogsRegistrationTest < Minitest::Test
  def setup
    RecordingStudioEmbeddable.reset_configuration!
  end

  def teardown
    RecordingStudioEmbeddable.reset_configuration!
  end

  def test_gemspec_pins_recording_studio_logs_like_api
    gemspec = File.read(File.expand_path("../recording_studio_embeddable.gemspec", __dir__))

    assert_includes gemspec, 'spec.add_dependency "recording_studio_logs", ">= 0.7.1", "< 1.0"'
  end

  def test_register_keeps_unpartitioned_table_and_omits_actor_ip_request_fields
    RecordingStudioEmbeddable::LogsRegistration.register!
    log = RecordingStudioLogs.registry.log_for(RecordingStudioEmbeddable::LogsRegistration::SOURCE_MODEL)

    assert_equal :viewed_at, log.timestamp_column
    assert_nil log.partition_interval
    assert_equal :root_recording_id, log.root_column
    assert_equal :indefinite, log.retention
    assert_empty RecordingStudioLogs.registry.aggregations_for(log)

    forbidden = RecordingStudioEmbeddable::LogsRegistration::FORBIDDEN_AGGREGATABLE
    aggregatable = log.contract.instance_variable_get(:@columns).keys
    forbidden.each do |column|
      refute_includes aggregatable, column
    end
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
