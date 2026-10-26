# Migration notes

## 0.13.0 — Recording Studio 6.1 layout

`RecordingStudio::UsesDefaultLayout` is gone. Management screens take their layout from `config.layout`.

1. Pin `recording_studio_embeddable` `0.13.0`, `recording_studio` `>= 6.1.0` (git tag `v6.1.0`), and `flat_pack` `>= 0.1.315`. This repository pins flatpack commit `1fcbafe94f8eb118f0a22182f63f5110fcc97a56` (`0.1.319`). Keep `view_component` at `>= 4.14`, `< 5`.
2. Leave `config.layout` unset or set it to `nil` to follow `RecordingStudio.configuration.layout`, then `"recording_studio/default_layout"`. Set `false` for no layout, a string for a layout name, or a `->(controller:) { ... }` callable. Anything else raises `ArgumentError`.
3. Remove `include RecordingStudio::UsesDefaultLayout` and `layout "recording_studio/default_layout"` from host controllers. `RecordingStudioEmbeddable::ApplicationController` calls `recording_studio_layout` with `config.layout`. A subclass that must switch layouts (the management modal) should call `recording_studio_resolved_layout` for the studio branch.
4. On studio pages, set `content_for :title` and `content_for :subtitle`. Replace `recording_studio_page_nav` with `flat_pack_page_nav(round: true, style: :default, back_href:, back_tooltip:, anchor_href:, anchor_tooltip:)`. Register page actions with `register_page_nav`. Do not also render `FlatPack::PageTitle` in the body. The default layout renders one heading.
5. Delete a host copy of `recording_studio/_default_layout_head` that links `flat_pack/application`. The v6 layout loads `flat_pack/variables`, `flat_pack/application`, and `flat_pack/rich_text` before Tailwind, and sets `data-theme="rounded"` on `<html>`.
6. Public iframe, popup, and launcher controllers keep their chromeless layouts. Do not point those at `recording_studio/default_layout`.
7. There is no migration. `frame-ancestors`, CORS, sanitizer allowlists, and `RecordingStudioAccessible.authorized?(role: :edit)` are unchanged.

Sibling gems pinned in this repository's Gemfile still declare `recording_studio` `~> 4.x`. `test/support/widen_recording_studio_requirement.rb` rewrites that dependency when Bundler loads those gemspecs. A host that has already bumped those gems should not copy the hook.

## 0.12.0 — RecordingStudioLogs for embed view logs

Existing `recording_studio_embeddable_view_logs` rows stay. The table is not
repartitioned. Hosts add `root_recording_id` and `arrived_at`; they do not
copy-and-switch or add a summary table.

1. Pin `recording_studio_embeddable` `0.12.0` and `recording_studio_logs` GitHub
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
