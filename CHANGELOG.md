# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.11.0] - 2026-10-21

### Added
- RecordingStudioLogs `>= 0.4.1, < 0.6` (dummy and development pin GitHub tag
  `v0.5.0`) for the existing embed view log. The raw table stays unpartitioned
  (`partition_interval: nil`, UUID `id`). New columns are `root_recording_id`
  (backfilled from the parent or embed recording) and `arrived_at`. Daily
  summaries live in `recording_studio_embeddable_view_day_summaries`
  (`embeddable/embed_views`).
- `config.logs_summaries_enabled` (default false). Unused by the stats screen,
  view-logging flags, sampling/privacy, rate limits, and Metrics while off.

### Changed
- `PruneViewsJob` still uses `config.prune_views_after` (default 90 days). With
  the summaries flag off it deletes raw rows older than that window. With the
  flag on it delegates to RecordingStudioLogs retention (a UTC day is removed
  only after a covering `embeddable/embed_views` success). Hosts that already
  schedule `PruneViewsJob` do not need a new job name.

### Upgrade notes
- Bump to `recording_studio_embeddable` `0.11.0` and pin
  `recording_studio_logs` to GitHub tag `v0.5.0` (allowed range
  `>= 0.4.1, < 0.6`).
- If Logs run tables are not present, run
  `bin/rails generate recording_studio_logs:migrations`. Then run
  `bin/rails generate recording_studio_embeddable:migrations` and
  `bin/rails db:migrate`. Existing `recording_studio_embeddable_view_logs`
  rows are kept.
- Leave `config.logs_summaries_enabled` false. Optional: after comparing
  daily totals, set it true and schedule `RecordingStudioLogs::DailyAggregationJob`
  (and `ReconciliationJob`) before relying on Logs prune. Do not schedule
  partition maintenance for this unpartitioned table.

## [0.10.0] - 2026-10-16

### Changed
- The engine no longer adds its `lib/` directory to Rails `autoload_paths` or
  `eager_load_paths`. Zeitwerk therefore does not try to eager-load gem `lib/`
  (including generators and already-required files). Host apps no longer need
  to strip `RecordingStudioEmbeddable::Engine.root.join("lib")` from those
  paths. Library code under `lib/` still loads through the gem entrypoint
  requires; helpers and models under `app/` stay on the engine's normal
  autoload paths.
- Because `lib/` is no longer on the autoload paths, edits under gem `lib/` are
  not reloadable in development — restart the process after changing those
  files. Engine `app/` code remains reloadable as before.

### Upgrade notes
- Bump to `recording_studio_embeddable` `0.10.0` first, then remove the
  featured_in-style initializer workaround that strips this engine's `lib/`
  from `config.eager_load_paths` / `config.autoload_paths`. Removing that
  strip on `<= 0.9.0` breaks eager load. No migration.

## [0.9.0] - 2026-10-16

### Changed
- Public embed rate limiting now uses shared
  `RecordingStudioCache::RateLimiter` (`recording_studio_cache` `~> 0.5`,
  git tag `v0.5.0`). Host config keys stay the same (`rate_limiter`, `redis`,
  `rate_limit`, `rate_limit_window`, `rate_limit_fail_closed`,
  `rate_limiting_enabled`). `RateLimiters::{Null,RailsCache,Redis}` remain as
  thin adapters (same `allow?(key:, limit:, window:)` surface). Fixed-window
  keys stay `recording_studio_embeddable:rate:<key>:<bucket>`; HTTP `429` still
  sets `Retry-After` to `rate_limit_window`; backend errors still follow
  `rate_limit_fail_closed` via `rescue_errors: [StandardError]`.
  `:rails_cache` still uses `Rails.cache` (main had no gem `cache_store`
  setting — not `RecordingStudioCache.store`).
- Adapters keep main's edge-case outcomes that the shared limiter does not:
  `limit.to_i <= 0` (including `nil` / `""`) still **blocks** (main compared
  `count.to_i <= limit.to_i`; shared treats `limit <= 0` as disabled/allow);
  non-positive / blank windows still follow `rate_limit_fail_closed` (main
  raised `ZeroDivisionError` on `window.to_i` in the key, then rescued).
  String windows/limits such as `"60"` / `"5"` still work via `.to_i`.
  Blank keys raise `ArgumentError` from the shared limiter; adapters map that
  through `rate_limit_fail_closed` (outer rescue). Redis clients that only
  implement `incr` / `expire` (no `eval`) still raise `ArgumentError`.
- Key TTL: main already applied `expires_in` (rails_cache) and `EXPIRE`
  (redis). Shared still TTLs keys — this is not a new TTL where none existed.
  Redis TTL is no longer refreshed on every hit (Lua sets `EXPIRE` when
  `count == 1` or `TTL == -1`); fixed-window bucket keys still expire with the
  window.
- Version bump to `0.9.0`.

### Upgrade notes
- Bump to `recording_studio_embeddable` `0.9.0` and add
  `recording_studio_cache` `~> 0.5` (pin git tag `v0.5.0` until published).
  No migration.
- Redis rate-limiter clients must respond to `eval` (Lua). Clients that only
  implement `incr` / `expire` now raise `ArgumentError` from the shared
  limiter. Pass a full Redis client via `config.redis` (or as
  `config.rate_limiter` when that object responds to `incr`, as before).
  This is the deliberate parity break vs main's `incr`/`expire` path.

## [0.8.0] - 2026-10-15

### Added
- Optional modal for embed management. `recording_studio_embeddable_management_modal(recording:, tab: :styling)` opens Embed, Preview, Embed style, Settings, the floating screen, or Stats in a Flatpack modal.
- The modal uses Flatpack `scroll: :page` and `body_height_mode: :auto`, so the dialog follows the content. Close it with the Flatpack X, Escape, or the backdrop.
- Management responses for Turbo Frame `recording_studio_embeddable_management`, `?variant=modal`, or `?modal=1` render inside that frame, without the page back and close bar. Tab links and forms stay in the frame. A successful save redirects inside the frame. A 422 re-renders the frame with the errors.
- Embed style is two columns. Controls and Save are on the left. The live preview is on the right. Save sits under the controls. Colour swatches wrap onto the next line (`flex flex-wrap`) instead of scrolling sideways.
- Every management screen has a tab: Embed, Preview, Embed style, Chat button (when the type floats), Settings, and Stats. The open screen's tab is a primary button. The others stay secondary. That row is on the full page and in the modal. Switching tabs renders that screen again, so the primary tab moves with the screen.
- Preview is the management screen: the embed document sits in a frame under those tabs. The document itself is the same path with `?document=1`. Embed style's live preview uses that document URL. The document still forces a full load (`turbo-visit-control`) and allows same-origin framing.
- The dummy app shows the modal for a Page and for the floating Widget at `/embed-modals`.

### Changed
- The floating snippet tells people to add it on every page, just before the closing `</head>` tag.
- The Embed screen tells people to put the iframe markup in the page HTML where the recording should appear.
- Neither help text mentions Squarespace, Wix, or WordPress.

### Upgrade notes
- Bump to `recording_studio_embeddable` `0.8.0`. No migration and no compatibility shim.
- Full-page Embed style, Settings, Stats, and Preview show the same tab row as the modal. Opening Preview shows that screen. The bare embed document is `?document=1` on the preview path.
- The styling tab uses `management.styling.title` ("Embed style").
- Call `ensure_embed!` before the helper. `tab` accepts `:edit`, `:preview`, `:styling`, `:settings`, `:floating`, and `:stats`.

## [0.7.0] - 2026-10-13

### Added
- Opt-in floating launcher for embeddable types via
  `RecordingStudio::Capabilities::Embeddable.to(floating: true, floating_popup: { controller:, action: })`.
  Types that do not opt in (Page, Article) never float.
- `floating_enabled` and `floating` jsonb on embeds. Launcher settings are
  validated (position, edge spacing, popup size, allowlisted or Attachable icon).
  Launcher colours come from the existing embed theme.
- `GET /recording_studio_embeddable/embeds/:token/launcher` returns JSON config.
  Public id is `embed.token`. CORS echoes an allowlisted `Origin`, never `*`,
  and fails closed when `Origin` is missing. `popup_url` is built per request
  and is not stored.
- Stable `GET /recording_studio_embeddable/widget.js` launcher script, plus
  `recording_studio_floating_widget` and `recording_studio_floating_widget_snippet`.
  The local helper renders the same JSON as the endpoint. The snippet does not.
- `RecordingStudioEmbeddable::FloatingWidget::Interactive` for host popup
  controllers: frame-ancestors from the domain allowlist, private no-store,
  rate limit, and a path-scoped `SameSite=None; Secure; Partitioned` CSRF cookie
  that does not use the host session. `widget_bridge.js` posts close and resize
  to an explicit parent origin. Popups are not published to Artifacts.
- Launcher management screen for types that opt in: enable, Position radios
  (Bottom left or Bottom right, default Bottom right when unset), the install
  snippet with its copy control, and a live preview. The Embed screen keeps
  only the inline embed code. Style still owns accent colours.
- Edge spacing, panel size, and the icon are host configuration:
  `floating_options` on `Embeddable.to`, falling back to
  `config.floating_defaults`. They are not stored on the embed and not shown
  on the launcher form. Launcher JSON still emits the host values.
- The management name for the launcher is host configuration too: `label` on
  `floating_options`, then `config.floating_defaults`, then "Floating button".
  Tab, heading, form copy, snippet section, and the save flash
  interpolate `%{label}`. Routes and form ids stay `launcher`.
- The launcher management preview uses the same iframe frame as Style and
  loads the production `widget.js`. The popup starts open, at the host size,
  and stays inside the frame. Position radios move it. The button toggles it.

### Upgrade notes
- Bump to `recording_studio_embeddable` `0.7.0` and run migrations. New columns:
  `recording_studio_embeddable_embeds.floating_enabled` (boolean, default false)
  and `floating` (jsonb, default `{}`).
- No compatibility shim. Existing inline embeds stay inline until a type opts in
  and a person enables the launcher.
- Host popup routes must accept `:token` and match `floating_popup`.
- Optional `config.floating_icon_hosts` allowlists icon URL hosts. Attachable
  direct URLs on the parent recording are allowed without that list.
- Set spacing, panel size, and `icon_url` with `floating_options:` or
  `config.floating_defaults`. The strip migration deletes those keys from
  existing `floating` jsonb. The launcher form no longer edits them.
- Optional `label` on `floating_options` or `config.floating_defaults` names
  the launcher on the management screen. The default word is "Floating button".
- `RenderPayload`, `HtmlSanitizer`, and CDN publish ignore floating settings.

## [0.6.0] - 2026-10-13

### Added
- Dummy committed encrypted `config/credentials/test.yml.enc` (same shared RS
  key and shape as `development.yml.enc`). Gitignored `test.key` / `*.key` /
  `master.key` stay local. CI boots without a key (`require_master_key = false`)
  and keeps MemoryStorage + dummy hosts via `DummyDevCredentials`.
- English Rails I18n under `recording_studio.embeddable` in `config/locales/en.yml`.
  Every `t(...)` / `I18n.t(...)` passes English `default:` so a host locale
  without a fallback never shows "translation missing".
- Host English override coverage: test-only fixture
  `test/dummy/test/locales/embeddable_host_override.en.yml` plus a real-page
  assert; always-loaded boot-order guard
  `test/dummy/config/locales/recording_studio_embeddable_host.en.yml` for the
  rarely shown `flashes.styling_disabled` key.
- Locale regression: every `lib/**/*.rb` file must not mention `i18n.load_path` /
  `I18n.load_path`. Engine exposes `config/locales/en.yml` without an explicit
  load-path initializer.
- Validation i18n coverage for the string-typed invalid-domain error: English
  `errors.details` stays byte-identical to main; non-English locales and host
  overrides carry the translated string as the error type.

### Changed
- Management views, flashes, stats filter labels, public not-found empty state,
  and domain validation copy resolve through `t(..., default: <main English>)`
  (English output unchanged).
- Version bump to `0.6.0`.

### Upgrade notes
- Bump to `recording_studio_embeddable` `0.6.0`. No migration.
- English hosts need no change. Override by defining the same nested keys under
  `recording_studio.embeddable` in host `config/locales`.
- No dependency on `recording_studio_internationalization`.
- Recordable `label` / `plural_label`, OpenAPI strings, generator CLI text,
  developer `ArgumentError`s / service failures, CDN unavailable HTML
  (`UNAVAILABLE_HTML`), CDN/published embed document chrome (layout `<title>`,
  rich-body fallbacks and Gallery heading — English literals as on main), and
  public helpers that return data (including `embed_code` iframe title default)
  stay English literals so published HTML is locale- and host-override-stable.
- For the string-typed `Invalid embedder domain: …` validation, `errors.details`
  carries the translated string in non-English locales (English unchanged).

## [0.5.1] - 2026-10-09

### Fixed
- Dummy host wires `recording_studio_root_switchable` + `AdminRoot` so
  RecordingStudioApi admin HTML (`/recording_studio_api/admin_api` and
  settings / rate_limiting / requests / errors / logs) resolves
  `current_root_recording` instead of raising `NameError`.

### Upgrade notes
- Dummy / hosts that mount RecordingStudioApi admin browser pages need
  `recording_studio_root_switchable`, an `AdminRoot` recordable, Accessible
  grants on that root, and RootSwitchable defaulting to AdminRoot (see
  `test/dummy` and the API gem dummy). No engine API change.

## [0.5.0] - 2026-10-08

### Added
- Rich Flatpack embed body (shared `_rich_body`) with title, description, cover
  image, and gallery. Images use Attachable **direct** URLs (`url_mode: :direct`)
  with `srcset`/`sizes` across preprocessed variants, `loading="lazy"` (eager for
  the cover), and explicit `width`/`height`.
- `DirectImageUrls` + `DirectImageHelper` — build image tags from Attachable's
  public API only (`original_url` / `url_for_variant` with `mode: :direct`,
  `variant_processed?`). Unprocessed variants are omitted from `srcset` instead
  of falling back to Rails preview paths.
- `EnsureEmbedImageVariants` — before Artifacts publish, runs Attachable's
  `PreprocessVariantsJob` synchronously for every image on the recording and
  verifies `variant_processed?` for each configured preprocessed name.
- `PublishedHtmlGuard` — refuses to publish HTML that still contains
  `/rails/active_storage` or Attachable Rails preview/file paths. If variants
  are not ready after sync processing, publish **defers** and re-enqueues
  `PublishEmbedToCdnJob` (`config.cdn_variant_retry_wait`, default 15s).
- Dummy Attachable pin `v0.9.0` with `direct_url_host = "cdn.example.test"`,
  seed cover + gallery fixtures on **every** embeddable example (Page + Article),
  and a dummy-only `DummyCdnController` / `DummyCdnHost` middleware so direct
  URLs resolve locally for screenshots.
- Dummy local R2 wiring without committing plaintext secrets: development reads
  Active Storage `:r2`, `recording_studio_artifacts.cdn`, and
  `recording_studio_attachable.direct_url_host` from committed encrypted
  `config/credentials/development.yml.enc` (gitignored `development.key`);
  CI / clones without the key keep dummy fallbacks.

### Changed
- Version bump to `0.5.0`.
- Public embed 404 EmptyState title is **Oops** with heroicon `exclamation-circle`
  (still HTTP 404, still Flatpack EmptyState).
- Runtime dependency on `recording_studio_attachable` `~> 0.9`.
- Pin `flat_pack` to `~> 0.1.207` (Attachable 0.9 requires `>= 0.1.205`).
- CI installs **libvips** so dummy direct-image / CDN publish tests can run
  Attachable `PreprocessVariantsJob` (Active Storage `:vips`).
- Embed figure captions use Flatpack Carousel-style layout: `overflow-hidden` +
  radius on the media wrapper only, `figcaption` with `px-4 py-3` so caption
  text is not clipped on the left edge.

### Upgrade notes
- Bump the gem to `0.5.0` and add/upgrade `recording_studio_attachable` to
  `~> 0.9` (GitHub tag `v0.9.0`).
- For direct image URLs on embeds, set Attachable:
  `config.url_mode = :direct` and `config.direct_url_host = "images.example.com"`.
  Calling `:direct` without a host raises `RecordingStudioAttachable::ConfigurationError`.
- Ensure Active Storage `track_variants` stays enabled. Default preprocessing is
  `small`/`med`/`large` plus host-added `image_variants` names.
- No data migration. Existing embeds republish on the next CDN job; HTML then
  uses direct host URLs only when images are present and variants are processed.

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
- Dummy seeds bootstrap Accessible owner access with
  `bootstrap_owner_access!` (then `grant_access` for the viewer). Plain
  `grant_access` for the first admin fails closed, which left publishable
  edit/preview as empty `403` / `404`.
- Dummy mounts a Flatpack Artifacts home at `/recording_studio_artifacts`
  so the engine root is not a blank `head :ok`. Optional
  `RECORDING_STUDIO_ARTIFACTS_ENABLED=true` flips the dummy switch for
  local/screenshot runs without changing the default.

### Upgrade notes
- Bump the gem to `0.4.0`.
- Artifacts/CDN usage is off by default. Hosts that already publish via
  Artifacts must set `config.artifacts_enabled = true` (and keep
  `embed_url_strategy = :cdn` where needed).
- No data migration. Existing `metadata.artifact` rows stay; with Artifacts off,
  `embed_code` / public URLs fall back to `/recording_studio_embeddable/embeds/:token`.
- Hosts that seed Accessible the way the old dummy did (`grant_access` for the
  first admin with no manager) should switch the first grant to
  `bootstrap_owner_access!`.

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

[Unreleased]: https://github.com/bowerbird-app/RecordingStudio_Embeddable/compare/v0.9.0...HEAD
[0.9.0]: https://github.com/bowerbird-app/RecordingStudio_Embeddable/compare/v0.8.0...v0.9.0
[0.8.0]: https://github.com/bowerbird-app/RecordingStudio_Embeddable/compare/v0.7.0...v0.8.0
[0.7.0]: https://github.com/bowerbird-app/RecordingStudio_Embeddable/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/bowerbird-app/RecordingStudio_Embeddable/releases/tag/v0.6.0
[0.3.0]: https://github.com/bowerbird-app/RecordingStudio_Embeddable/releases/tag/v0.3.0
[0.2.1]: https://github.com/bowerbird-app/RecordingStudio_Embeddable/releases/tag/v0.2.1
[0.2.0]: https://github.com/bowerbird-app/RecordingStudio_Embeddable/releases/tag/v0.2.0
[0.1.3]: https://github.com/bowerbird-app/RecordingStudio_Embeddable/releases/tag/v0.1.3
[0.1.2]: https://github.com/bowerbird-app/RecordingStudio_Embeddable/releases/tag/v0.1.2
[0.1.1]: https://github.com/bowerbird-app/RecordingStudio_Embeddable/releases/tag/v0.1.1
[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_Embeddable/releases/tag/v0.1.0
