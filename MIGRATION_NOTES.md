# Migration notes

## 0.11.0 — RecordingStudioLogs for embed view logs

Existing `recording_studio_embeddable_view_logs` rows stay. The table is not
repartitioned. Hosts add columns and a summary table; they do not copy-and-switch.

1. Pin `recording_studio_embeddable` `0.11.0` and `recording_studio_logs` GitHub
   tag `v0.5.0` (`>= 0.4.1, < 0.6`).
2. If `recording_studio_logs_aggregation_runs` is missing, run
   `bin/rails generate recording_studio_logs:migrations`.
3. Run `bin/rails generate recording_studio_embeddable:migrations` and
   `bin/rails db:migrate`. That adds `root_recording_id` and `arrived_at` on the
   view log (backfilled), plus `recording_studio_embeddable_view_day_summaries`.
   The Embeddable summary migration also installs Logs run tables when they are
   absent.
4. Keep scheduling `RecordingStudioEmbeddable::PruneViewsJob` if you already do.
   Retention is still `config.prune_views_after` (90 days).
5. Leave `config.logs_summaries_enabled` false. Stats, sampling, privacy flags,
   rate limits, and Metrics stay on the previous path. When you turn the flag
   on, rebuild summaries (`FROM=… TO=… bin/rails recording_studio_embeddable:view_logs:backfill_summaries`)
   and schedule Logs `DailyAggregationJob` / `ReconciliationJob`. Then prune
   waits for a covering success per UTC day. Do not schedule
   `PartitionMaintenanceJob` for this table.

Rollback is turning the flag off. Raw rows deleted after a successful Logs prune
do not come back.

---

# Historical notes — private gems to public gems

## Changes Made

1. ✅ Removed repository access entries from `.devcontainer/devcontainer.json`
2. ✅ Updated documentation in `CODESPACES.md` and `PRIVATE_GEMS.md`
3. ✅ Updated copilot instructions to reference local docs
4. ✅ Replaced `makeup_artist` with `flat_pack` in `test/dummy/Gemfile`

## Next Steps (Requires Ruby 3.3.0+)

The following steps need to be completed in an environment with Ruby 3.3.0 or higher:

1. **Update Gemfile.lock**: Run `bundle install` in the test/dummy directory to update the lockfile
   ```bash
   cd test/dummy
   bundle install
   ```

2. **Run FlatPack installer**: After bundle install, run the FlatPack installation generator
   ```bash
   cd test/dummy
   rails generate flat_pack:install
   ```

3. **Update views**: Replace any `makeup_artist` component references with `flat_pack` components
   - Search for: `MakeupArtist::`, `makeup_artist/`
   - Replace with equivalent FlatPack components

4. **Test the application**: Start the dummy app and verify all UI components work
   ```bash
   cd test/dummy
   bin/dev
   ```

5. **Run tests**: Execute the test suite
   ```bash
   bundle exec rake test
   ```

## Component Migration Guide

FlatPack is the successor to MakeupArtist with similar components:

- Both use ViewComponent architecture
- Both integrate with Tailwind CSS
- Component names and APIs may differ slightly

See: https://github.com/bowerbird-app/flatpack for component documentation
