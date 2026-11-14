---
description: "Use when writing or updating Minitest coverage, regression tests, generator tests, or validation steps for this Rails engine template."
applyTo: "test/**/*.rb"
---

# Testing Guidelines

- Use Minitest for engine and template coverage.
- Prefer focused regression tests for hooks, generators, Recording Studio integration points, and template UX guidance.
- Run `bundle exec rake test` from the repository root for the gem suite.
- Run `bundle exec rake test:all` for the gem suite, the dummy suite, and merged SimpleCov over `app/` and `lib/`. That task fails when line coverage is under 94%. CI runs this command. Build dummy Tailwind first (`bin/rails tailwindcss:build` in `test/dummy`); the gem suite reads the gitignored CSS build. `test/dummy/config/boot.rb` starts SimpleCov before `bin/rails test` boots the app, so library code loaded at boot is included.
- If a change affects dummy app boot, assets, or migrations, also validate the dummy app path the same way CI does.
- Keep tests deterministic and fix production code rather than weakening assertions to make tests pass.