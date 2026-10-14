RecordingStudioLists install complete.

Next steps:

1. Review config/initializers/recording_studio_lists.rb and set any required options.
2. If you use environment-specific settings, create config/recording_studio_lists.yml.
3. Ensure `recording_studio_orderable` is in the Gemfile, then install its migrations with
   `bin/rails generate recording_studio_orderable:migrations` (lists stores member order there).
4. Install the lists migrations with `bin/rails generate recording_studio_lists:migrations`.
5. Apply the migrations with `bin/rails db:migrate` (Orderable before the lists position move).
6. Run `bin/rails tailwindcss:build` if you use Tailwind CSS.
7. Mount routes are added at the configured mount path. Adjust auth, layout, and current actor integration to match your host app.
8. Keep strict recordable declarations enabled and add `recording_studio_recordable(...)` to every configured recordable before running `RecordingStudio.validate_recordable_declarations!`.