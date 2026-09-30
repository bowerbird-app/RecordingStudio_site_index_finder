Site Index Finder install complete.

Next steps:

1. Review config/initializers/recording_studio_site_index_finder.rb and set any required options.
2. If you use environment-specific settings, create config/recording_studio_site_index_finder.yml.
3. Run `bin/rails tailwindcss:build` if you use Tailwind CSS.
4. Mount routes are added at the configured mount path. Adjust auth, layout, and current actor integration to match your host app.
5. Keep strict recordable declarations enabled and add `recording_studio_recordable(...)` to every configured recordable before running `RecordingStudio.validate_recordable_declarations!`.

Site Index Finder does not add database tables. There is no migration to install.
