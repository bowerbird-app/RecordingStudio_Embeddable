# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.4.0] - 2026-10-08

### Added
- `config.artifacts_enabled` (default `false`) — explicit host-wide Artifacts/CDN
  usage switch. The Artifacts gem stays a hard dependency; the switch only
  controls whether Embeddable enqueues publish/purge jobs and returns CDN URLs.
  When off, partner URLs use the Rails mount even if an embed row still says
  `embed_url_strategy: "cdn"`. Turning OFF does not delete R2 objects.
- Public embed `404` renders a Flatpack `EmptyState` (with icon) in the embed
  layout instead of a bare `head :not_found`. Same generic copy for missing /
  disabled / unpublished tokens — no leaked detail. Artifacts “unavailable”
  CDN document is unchanged.
- DomainPolicy treats same-origin Referer/Origin as allowed so opening the
  dedicated public path from the host app no longer returns an empty `403`.
- Management Preview forces a full document load (`turbo-visit-control` +
  `data-turbo="false"`) and allows same-origin framing so the preview is not
  blank under Turbo Drive / styling iframes.

### Changed
- Version bump to `0.4.0`.

### Upgrade notes
- Bump the gem to `0.4.0`.
- Artifacts/CDN usage is off by default. Hosts that already publish via
  Artifacts must set `config.artifacts_enabled = true` (and keep
  `embed_url_strategy = :cdn` where needed).
- No data migration. Existing `metadata.artifact` rows stay; with Artifacts off,
  `embed_code` / public URLs fall back to `/recording_studio_embeddable/embeds/:token`.

## [0.3.0] - 2026-10-07

### Added
- CDN publish via `recording_studio_artifacts` (`~> 0.4.0`): `PublishEmbedToCdn` /
  `PublishEmbedToCdnJob` pre-render iframe HTML and call
  `RecordingStudioArtifacts.publish` (first time) or `.update` (re-publish).
  Partner URLs are Artifacts public URLs
  (`https://{sub}.{domain}/recording_studio_artifacts/{uuid}`).
- `embed_url_strategy: "cdn"` flips `public_path` / `embed_public_url` /
  `embed_code` to the stored Artifacts URL only — never the App Platform mount
  `/recording_studio_embeddable/embeds/:token`.
- `recording.enqueue_embed_cdn_publish!` for parent recording / theme / publishable changes.
- Domain allowlist baked at publish (`DomainPolicy#frame_ancestors` → HTML CSP marker).
- `docs/CDN.md` for Artifacts consumer wiring (no Spaces).
- Dummy installs Artifacts (create + revision/purge migrations + MemoryStorage
  initializer) so CDN publish is exercisable without real R2 credentials.
- Shared dummy credentials (`test/dummy/config/credentials.yml.enc`) include
  `recording_studio_artifacts.cdn` placeholder keys (`dev_placeholder`, fake
  `public_base_url`). Hosts still own real `ARTIFACT_CDN_*` / R2 secrets.
- Dummy mounts Recording Studio API at `/recording_studio_api` and allowlists GET `:embed` on Page. An AccessGrant client can fetch BrowserPayload schema v1 (`schema_version`, `html`, `configuration`, `sdk`) without a host-owned handler.

### Changed
- Pin `flat_pack` to `~> 0.1.198` (GitHub tag `v0.1.198`).
- Pin `recording_studio` to GitHub tag `v4.2.2` (still `~> 4.2` in the gemspec).
- Pin `recording_studio_accessible` to GitHub tag `v0.11.1` (gemspec stays `~> 0.9`, which already allows 0.11.x).
- Pin `recording_studio_publishable` to `~> 0.4` (GitHub tag `v0.4.2`).
- Pin `recording_studio_artifacts` to `~> 0.4.0` (GitHub tag `v0.4.0`).
- Dummy pins Attachable `v0.7.1` and Admin `v2.0.4`. API stays at `v0.5.5`.
- Dummy Accessible schema now includes access invitations and stores access roles as strings (`view`, `edit`, `admin`).
- Dummy API initializer exposes `RecordingStudio::Access.roles` from Accessible's ranked names so API `v0.5.5` can still authorize member actions.

### Removed
- DigitalOcean Spaces / `EMBED_CDN_*` publish path (closed PR #10). Artifacts → R2
  is the only CDN publish path.

### Upgrade notes
- Bump the gem to `0.3.0`. Add `recording_studio_artifacts` `~> 0.4.0`
  (GitHub tag `v0.4.0`), run Artifacts install + migrations (including
  `revision` / `purge_error` / `purged_at`), and set `ARTIFACT_CDN_*`
  (or credentials). `aws-sdk-s3` is a runtime dependency of Artifacts `0.4.0+`.
- Drain or ignore in-flight Artifacts `PublishArtifactJob` jobs that used a
  single `artifact_id` argument; `0.4.0` jobs take `(artifact_id, revision)`.
  Embeddable does not enqueue that job.
- Purge failures no longer fail an Artifacts publish (`purge_error` is recorded
  instead). Embeddable still treats publish/update success as the CDN publish
  success signal.
- Embeddable does not destroy embeds and does not call
  `RecordingStudioArtifacts.unpublish`. Disable overwrites the same artifact with
  an unavailable document so the partner URL stays stable. Hosts that need to
  remove the R2 object can call `unpublish(id:)` and clear `metadata.artifact`.
- To serve partners from CDN: set `config.embed_url_strategy = :cdn` (or per-embed),
  configure Artifacts public base / R2, and call `enqueue_embed_cdn_publish!` after
  parent content, theme, or publishable changes.
- Embed metadata stores `artifact.id` + `artifact.public_url`. Do not point hosts at
  Spaces object keys or `EMBED_CDN_SPACES_*`.
- `EmbedsController` remains as an optional origin fallback during migration.
  Partner snippets must use the Artifacts URL once strategy is `cdn`.
- CDN hits do not run `CaptureView` or Rails rate limiting — use Cloudflare analytics /
  rate limits. Browser-payload / API embeds are unchanged. Pretty-URL CF Worker is deferred.
- Hosts that use Publishable with this gem need Publishable `~> 0.4` (for example tag `v0.4.2`).
- Accessible `0.11` stores roles as strings and adds access invitations. Hosts moving from Accessible `0.9.x` must run Accessible's 0.8–0.11 migrations and `db:migrate`.
- Recording Studio API stays on `v0.5.5` here. That tag still expects `Access.roles`. Dummy shims it; hosts on API 0.5.x with Accessible 0.11 should do the same until API is compatible with Accessible 0.11.

## [0.2.1] - 2026-09-15

### Changed
- Pin `recording_studio_accessible` to `~> 0.9` (GitHub tag `v0.9.1`).
- Soft-registered `:embed` uses Accessible role `:view` for `required_role` and `authorize!`.

### Upgrade notes
- Bump the gem to `0.2.1`. Require Accessible `~> 0.9` (for example tag `v0.9.1`).
- Accessible `0.8+` adds `depends_on_recording_id`. Hosts moving from Accessible `0.7.x` must run Accessible's migration generator and `db:migrate`. Embeddable itself adds no migration.
- `:embed` no longer declares or authorizes `:read`. Accessible roles are `view`, `edit`, and `admin` only. A `:read` required_role fails Recording Studio API boot.
- Soft registration stays Moveable-style. There is still no hard gemspec dependency on `recording_studio_api`.
- Iframe public path, domain policy, cache, rate limit, management UI, `RenderPayload`, and `HtmlSanitizer` are unchanged.

## [0.2.0] - 2026-09-14

### Added
- Browser-payload mode for the WordPress Plugin Demo SDK: `RenderPayload` returns a `BrowserPayload` matching schema version 1 (`schema_version`, `html`, `configuration`, `sdk`).
- `HtmlSanitizer` (Loofah scrubber) strips `script` / `iframe` / `object` / `embed` / `link` / `meta`, `on*` attributes, and `javascript:` URLs at the Ruby boundary.
- Soft `:embed` capability-action registration via `RecordingStudioEmbeddable::Api` when `recording_studio_api` is present (Moveable-style; no gemspec dependency).
- `Api.descriptor` hash for discoverability; `Api::EmbedRecording` returns `payload.to_h` and does not call `CaptureView`.

### Changed
- README documents iframe mode and browser-payload mode, including the view-logging policy.
- Pin `flat_pack` to `~> 0.1.143` (GitHub tag `v0.1.143`).
- Replace Style width chips (Full / Readable / Compact) with a round FlatPack Button in the OverflowRow. Order is FontSwatch, width Button (tooltip-only “Width”), ColorSwatches. The popover has a Width heading and FlatPack Tabs (`Auto` / `Custom`). Auto has no field (`100%` fill). Custom has one TextInput with help_text `% or px`. Height stays `auto`.
- Replace `Styling::WidthPresets` with `Styling::WidthMode` (`auto` vs `custom`). Legacy Readable/Compact values load as Custom.

### Upgrade notes
- Bump the gem to `0.2.0`. No host migration is required.
- Iframe public path, domain policy, cache, rate limit, management UI, and `CaptureView` behavior are unchanged.
- Call `RecordingStudioEmbeddable::RenderPayload.call(recording:, embed:)` for fragment payloads. Do not route SDK/API embeds through `EmbedsController` if you need to avoid public view counts — browser-payload / API embeds intentionally do **not** log public iframe views.
- If the host loads `recording_studio_api`, the engine registers a member `:embed` GET action with `required_role: :view` automatically. Hosts that already register `:embed` keep their existing action.
- Payload `sdk.minimum_version` is `"0.3.0"` (WordPress Plugin Demo SDK). `configuration` exposes allowlisted `theme` tokens and `sizing` keys only (`width`, `mode`, `max_width`, `min_height`, `height`).

## [0.1.3] - 2026-09-02

Cloud Agent Builds for this gem now match Billing 0.9.13. Boot files are
tracked. A warm snapshot skips provision and still fetches skills.

### Added
- `.cursor/fetch-skills.sh`, `.cursor/install.sh`, `.cursor/start.sh`, and
  `.cursor/environment.json` for Cloud Agent boot. Install skips apt,
  ruby-build, db:prepare, and tailwind when Ruby, bundle, and Postgres are
  already usable. A skippable provision failure does not fail the Build.
  Fetch-skills always runs last. Start only brings PostgreSQL up.

### Upgrade notes
- No host or schema changes. Rebuild the Cloud Agent environment with Draft
  off so Build loads the pack. Product embed behavior is unchanged.

## [0.1.2] - 2026-08-29

### Changed
- Pin `flat_pack` to `~> 0.1.141` (GitHub tag `v0.1.141`) in the gemspec, root Gemfile, and dummy Gemfile/locks.
- Replace the long Styling colour form with FlatPack `ColorSwatch` circles plus one FlatPack `FontSwatch` inside one FlatPack `OverflowRow` (`gap: :md`). Tooltip names only; no under-labels. Padding/radius and other non-font fields are no longer rendered on Styling.
- OverflowRow owns the one-row strip: hidden scrollbar, trailing fade only while more content remains to the right, fade clears at the end. No Embeddable overflow/fade CSS.
- Font posts a curated CSS `font-family` stack through FontSwatch’s hidden input (`embed[appearance][font_family]`). Legacy stack keys (`sans` / `serif` / `mono`) still resolve.
- Show a live embed preview (management preview iframe) below the swatch row on Style. Drop the separate Preview button from that screen.
- Title the Style screen “Style” (PageTitle and page nav). Subtitle remains the recordable name.
- OverflowRow order is FontSwatch first, then ColorSwatch circles.
- Move embed width onto Style under the live preview: FlatPack ChipGroup (`wrap: false`) with Full (`100%`), Readable (`40rem`), Compact (`24rem`), and Custom (reveals a Width TextInput). Height always saves as `auto`. Live preview width follows the selected chip before Save.
- Remove Width/Height fields from Settings; Settings keeps allowed/blocked domains and Save only.
- Default embed sizing height is `auto` (replacing `320px`).
- Reset restores ColorSwatch native colour inputs and the FontSwatch hidden input to resolved/default values, resets width to Full, and repaints the live preview.
- Show the recordable name as the default-size FlatPack PageTitle subtitle on Settings, Style, and Stats (no `large_subtitle`). Dummy Article/Document seed titles are human names (“Spring release”, “Workspace notes”), not capability notes.

### Fixed
- Calling `recording_studio_embeddable` now enables the `:embeddable` RecordingStudio capability on the recordable, so `RecordingStudioEmbeddable::Embed` can be recorded under embeddable parents such as Page.
- Management screens use core `recording_studio/default_layout` via `RecordingStudio::UsesDefaultLayout`. The customer-facing iframe keeps the chrome-free embed layout.
- Copy FlatPack `rounded` onto `<html>` and load `flat_pack/application` through `recording_studio/_default_layout_head` so OverflowRow fade/scrollbar chrome and charcoal primaries work under default_layout.
- Dummy Tailwind `@source` now resolves FlatPack and Recording Studio from `Gem.loaded_specs` / `Bundler.bundle_path` before each CSS build, so Switch and icon size utilities compile under vendor, CI, and local `BUNDLE_PATH`.
- Replace dummy table action stacks with FlatPack `Button::Dropdown` (icon `ellipsis-vertical`, `show_chevron: false`).
- Keep the embed enablement control as a FlatPack `Switch` labeled Embeddable.
- Remove placeholder dummy copy (`This text uses the main text color.`).
- Cap embed-code, settings, and styling forms with FlatPack `Grid` `cols: 2` (width cap only; fields stay one per row).
- Show the embed snippet in a wrapping FlatPack `TextArea` with short help “Paste this into your page.”
- Keep Embed title, recordable subtitle, and Preview/Styling/Settings/Stats nav on the embed-code screen.
- Title Settings as “Embed settings” with the recordable name as subtitle (domains only).
- Put Style Save and Reset in one row of separate FlatPack Buttons (Save primary).

### Upgrade notes
- Require FlatPack `~> 0.1.143` (tag `v0.1.143`) for `FlatPack::ColorSwatch::Component`, `FlatPack::FontSwatch::Component`, `FlatPack::OverflowRow::Component`, `FlatPack::Button::Component`, and `FlatPack::Popover::Component` on the Style screen.
- Hosts using `recording_studio/default_layout` for management screens must load `flat_pack/application` (core layout only ships variables + rich_text). This gem’s `recording_studio/_default_layout_head` does that when the host does not override the partial.
- No host migration is required for existing embed appearance data. Colour values still post from ColorSwatch native inputs. Font may now save as a CSS stack string from FontSwatch; stack keys continue to work when resolving themes.
- Existing embed `sizing.width` of `100%` maps to Auto; other leftover widths (including legacy Readable/Compact values) map to Custom on Style. Style save always writes `sizing.height` as `auto`.

## [0.1.1] - 2026-04-28

### Changed
- Bumped the dummy app FlatPack dependency from `0.1.2` to `0.1.33` and pinned it by tag in `test/dummy/Gemfile`

## [0.1.0] - 2025-12-04

### Added
- Initial release
- Rails mountable engine structure
- PostgreSQL with UUID primary keys support
- TailwindCSS v4 integration
- GitHub Codespaces devcontainer configuration
- Docker Compose setup with PostgreSQL and Redis
- Install generator for host applications
- Comprehensive README and documentation
- Basic test suite with Minitest

[Unreleased]: https://github.com/bowerbird-app/RecordingStudio_Embeddable/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/bowerbird-app/RecordingStudio_Embeddable/releases/tag/v0.3.0
[0.2.1]: https://github.com/bowerbird-app/RecordingStudio_Embeddable/releases/tag/v0.2.1
[0.2.0]: https://github.com/bowerbird-app/RecordingStudio_Embeddable/releases/tag/v0.2.0
[0.1.3]: https://github.com/bowerbird-app/RecordingStudio_Embeddable/releases/tag/v0.1.3
[0.1.2]: https://github.com/bowerbird-app/RecordingStudio_Embeddable/releases/tag/v0.1.2
[0.1.1]: https://github.com/bowerbird-app/RecordingStudio_Embeddable/releases/tag/v0.1.1
[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_Embeddable/releases/tag/v0.1.0
