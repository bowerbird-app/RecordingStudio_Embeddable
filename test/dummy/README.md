# Dummy App

This Rails app exists to validate the Recording Studio addon template in a real host application.

## What It Covers

- Devise authentication with a seeded admin user
- `Current.actor` wiring for Recording Studio events
- Root workspace plus seeded folder and page recordables
- FlatPack layout integration and Tailwind source scanning
- Mounted `RecordingStudio::Engine` route behavior inside a host app
- A starter sidebar menu and companion docs pages for gem-specific onboarding

## Quick Start

```bash
cd test/dummy
bundle install
bin/rails db:setup
bin/dev
```

Run the commands above from the dummy app directory, not the repository root.

Then open the app and sign in with:

- Email: `admin@admin.com`
- Password: `Password`

## Useful Routes

- `/` - embeddable dummy index with a table of page recordings and edit/preview actions
- `/recording_studio` - redirects to `/` while the mounted Recording Studio engine stays available under that prefix for non-root routes
- `/users/sign_in` - Devise sign-in page
- `/docs/install`, `/docs/config`, `/docs/recordable_types`, `/docs/recordings_tree`, `/docs/gem_views`, `/docs/methods` - starter sidebar pages to adapt for the gem
- `/dummy/pages/new` - add-page form used to create embeddable test pages
- `/up` - Rails health check

## Why This App Exists

Use this app to verify the generated addon experience before renaming the gem or copying patterns into another host app. If a layout, route, asset source, or Recording Studio initializer change breaks here, the template likely needs adjustment before reuse.

Authenticated dummy pages use `RecordingStudio::UsesDefaultLayout` and `recording_studio/default_layout`. Core PageNav owns back/close. Dummy copies FlatPack `rounded` onto `<html>` via `app/views/recording_studio/_default_layout_head.html.erb`. Docs navigation lives in `app/views/application/_app_nav.html.erb` as in-page dummy docs links, not as the product frame.

Tailwind scans FlatPack and Recording Studio from Bundler’s loaded gem paths. `bin/rails tailwindcss:build` and `tailwindcss:watch` write `app/assets/tailwind/gem_sources.css` from `Gem.loaded_specs` and `Bundler.bundle_path` before compiling, so Switch and icon size utilities work under vendor, CI, mise, and local `BUNDLE_PATH`.

Likewise, the home page in `app/views/home/index.html.erb` should stay a minimal demo surface for the gem's core feature. Do not turn it into a wall of documentation; the dedicated docs pages exist so deeper explanations can live in focused sections.
