# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- Management screens use core `recording_studio/default_layout` via `RecordingStudio::UsesDefaultLayout`. The customer-facing iframe keeps the chrome-free embed layout.
- Copy FlatPack `rounded` onto `<html>` through `recording_studio/_default_layout_head` so primaries are charcoal, not `:root` blue.
- Dummy Tailwind `@source` now resolves FlatPack and Recording Studio from `Gem.loaded_specs` / `Bundler.bundle_path` before each CSS build, so Switch and icon size utilities compile under vendor, CI, and local `BUNDLE_PATH`.
- Replace dummy table action stacks with FlatPack `Button::Dropdown` (icon `ellipsis-vertical`, `show_chevron: false`).
- Keep the embed enablement control as a FlatPack `Switch` labeled Embeddable.
- Remove placeholder dummy copy (`This text uses the main text color.`).
- Cap the embed-code form with FlatPack `Grid` `cols: 2` (width cap only; fields stay one per row).
- Shorten embed-code help to “Paste this into your page.”
- Keep Embed title, recordable subtitle, and Preview/Styling/Settings/Stats nav on the embed-code screen only. Settings, Styling, and Stats titles are the action name.
- Put Styling Save, Reset, and Preview in one row of separate FlatPack Buttons (Save primary).

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

[Unreleased]: https://github.com/bowerbird-app/RecordingStudio_Embeddable/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/bowerbird-app/RecordingStudio_Embeddable/releases/tag/v0.1.1
[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_Embeddable/releases/tag/v0.1.0
