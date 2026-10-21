# Migration notes

## 0.11.0 — RecordingStudioLogs for embed view logs

Existing `recording_studio_embeddable_view_logs` rows stay. The table is not
repartitioned. Hosts add `root_recording_id` and `arrived_at`; they do not
copy-and-switch or add a summary table.

1. Pin `recording_studio_embeddable` `0.11.0` and `recording_studio_logs` GitHub
   tag `v0.5.0` (`>= 0.4.1, < 0.6`).
2. Run `bin/rails generate recording_studio_embeddable:migrations` and
   `bin/rails db:migrate`. That adds and backfills `root_recording_id` and
   `arrived_at` on the view log.
3. Keep scheduling `RecordingStudioEmbeddable::PruneViewsJob` if you already do.
   It still deletes rows older than `config.prune_views_after` (90 days).
   RecordingStudioLogs registers this log with indefinite retention, so Logs
   cleanup does not prune it. Do not schedule `PartitionMaintenanceJob` for this
   table.

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
