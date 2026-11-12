RecordingStudioLists install complete.

Next steps:

1. Review config/initializers/recording_studio_lists.rb and set any required options.
2. If you use environment-specific settings, create config/recording_studio_lists.yml.
3. Ensure `recording_studio_accessible` and `recording_studio_orderable` are in the Gemfile.
   List screens check access through `authorize_recording!`. Show needs `:view`. New and create
   need `:edit` on the current root. Edit, update, destroy, add, and remove need `:edit` on the
   list. Install Accessible migrations
   with `bin/rails generate recording_studio_accessible:migrations`, then Orderable with
   `bin/rails generate recording_studio_orderable:migrations` (lists stores member order there).
4. Install the lists migrations with `bin/rails generate recording_studio_lists:migrations`.
5. Apply the migrations with `bin/rails db:migrate` (Orderable before the lists position move).
6. Run `bin/rails tailwindcss:build` if you use Tailwind CSS.
7. Mount routes are added at the configured mount path. Adjust auth, layout, and current actor integration to match your host app.
8. Keep strict recordable declarations enabled and add `recording_studio_recordable(...)` to every configured recordable before running `RecordingStudio.validate_recordable_declarations!`.
9. Grant Accessible access on the list recording or an ancestor (usually the root). Without a
   grant, list screens treat the list as missing.
10. To expose lists over Recording Studio API, add `recording_studio_api`, run its install and
    migrations, mount the engine, and enable `:api_access_point` on roots that hold API clients.
