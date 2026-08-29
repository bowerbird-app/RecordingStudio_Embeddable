# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.2] - 2026-08-29

### Changed
- Pin `flat_pack` to `~> 0.1.138` (GitHub tag `v0.1.138`) in the gemspec, root Gemfile, and dummy Gemfile/locks.
- Replace the long Styling colour form with a wrapping row of FlatPack `ColorSwatch` circles plus one FlatPack `FontSwatch` (tooltip names only; no under-labels). Padding/radius and other non-font fields are no longer rendered on Styling.
- Font posts a curated CSS `font-family` stack through FontSwatch’s hidden input (`embed[appearance][font_family]`). Legacy stack keys (`sans` / `serif` / `mono`) still resolve.
- Show a live embed preview (management preview iframe) below the colour + font controls on Styling. Drop the separate Preview button from that screen.
- Reset restores ColorSwatch native colour inputs and the FontSwatch hidden input to resolved/default values and repaints the live preview.
- Show the recordable name as the default-size FlatPack PageTitle subtitle on Settings, Styling, and Stats (no `large_subtitle`).

### Fixed
- Calling `recording_studio_embeddable` now enables the `:embeddable` RecordingStudio capability on the recordable, so `RecordingStudioEmbeddable::Embed` can be recorded under embeddable parents such as Page.
- Management screens use core `recording_studio/default_layout` via `RecordingStudio::UsesDefaultLayout`. The customer-facing iframe keeps the chrome-free embed layout.
- Copy FlatPack `rounded` onto `<html>` through `recording_studio/_default_layout_head` so primaries are charcoal, not `:root` blue.
- Dummy Tailwind `@source` now resolves FlatPack and Recording Studio from `Gem.loaded_specs` / `Bundler.bundle_path` before each CSS build, so Switch and icon size utilities compile under vendor, CI, and local `BUNDLE_PATH`.
- Replace dummy table action stacks with FlatPack `Button::Dropdown` (icon `ellipsis-vertical`, `show_chevron: false`).
- Keep the embed enablement control as a FlatPack `Switch` labeled Embeddable.
- Remove placeholder dummy copy (`This text uses the main text color.`).
- Cap embed-code, settings, and styling forms with FlatPack `Grid` `cols: 2` (width cap only; fields stay one per row).
- Show the embed snippet in a wrapping FlatPack `TextArea` with short help “Paste this into your page.”
- Keep Embed title, recordable subtitle, and Preview/Styling/Settings/Stats nav on the embed-code screen.
- Title Settings as “Embed settings” with the recordable name as subtitle. Labels are Width and Height.
- Put Styling Save and Reset in one row of separate FlatPack Buttons (Save primary).

### Upgrade notes
- Require FlatPack `~> 0.1.138` (tag `v0.1.138`) for `FlatPack::ColorSwatch::Component` and `FlatPack::FontSwatch::Component` on the Styling screen.
- No host migration is required for existing embed appearance data. Colour values still post from ColorSwatch native inputs. Font may now save as a CSS stack string from FontSwatch; stack keys continue to work when resolving themes.

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
