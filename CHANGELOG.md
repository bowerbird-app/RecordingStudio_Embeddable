# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- Pin `flat_pack` to `~> 0.1.143` (GitHub tag `v0.1.143`).
- Replace Style width chips (Full / Readable / Compact) with a round FlatPack Button in the OverflowRow. Order is FontSwatch, width Button (tooltip-only “Width”), ColorSwatches. The popover has a Width heading, Auto (`100%`), Custom, and the typed CSS width field inside the popover on both modes. Height stays `auto`.
- Replace `Styling::WidthPresets` with `Styling::WidthMode` (`auto` vs `custom`). Legacy Readable/Compact values load as Custom.

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

[Unreleased]: https://github.com/bowerbird-app/RecordingStudio_Embeddable/compare/v0.1.2...HEAD
[0.1.2]: https://github.com/bowerbird-app/RecordingStudio_Embeddable/releases/tag/v0.1.2
[0.1.1]: https://github.com/bowerbird-app/RecordingStudio_Embeddable/releases/tag/v0.1.1
[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_Embeddable/releases/tag/v0.1.0
