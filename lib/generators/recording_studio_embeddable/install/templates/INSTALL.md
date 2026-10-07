RecordingStudioEmbeddable install complete.

Next steps:

1. Review config/initializers/recording_studio_embeddable.rb and set any required options.
2. If you use environment-specific settings, create config/recording_studio_embeddable.yml.
3. Install the engine migrations with `bin/rails generate recording_studio_embeddable:migrations`.
4. Apply the migrations with `bin/rails db:migrate`.
5. For CDN partner URLs, install `recording_studio_artifacts` (~> 0.3.0), run its
   install + migrations generators, set `ARTIFACT_CDN_*`, and set
   `config.embed_url_strategy = :cdn`. See docs/CDN.md.
6. Run `bin/rails tailwindcss:build` if you use Tailwind CSS.
7. Mount routes are added at the configured mount path. Adjust auth, layout, and current actor integration to match your host app.
