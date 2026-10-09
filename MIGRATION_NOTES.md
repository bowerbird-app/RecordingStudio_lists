# Migration Notes

## Upgrading To 0.4.0

This is a non-breaking upgrade. Rendered English interface text is unchanged.
Callers that pass their own `text:` (or other labels) to
`recording_studio_add_to_list` keep working.

### What Changed

- Static copy in the gem's own lists views and add-to-list partial uses Rails
  I18n keys under `recording_studio.lists`.
- The gem ships English only in `config/locales/en.yml` (Rails engines load
  that path by default). There is no dependency on
  `recording_studio_internationalization`.

Left untranslated on purpose: list names and descriptions, flash notices and
alerts from the controller, JS client error strings, icon/style tokens, the
add-to-list row template placeholder `Name` (replaced by JavaScript), and
dummy app views.

### Upgrade Steps

No migration is required. English hosts need no change. To override or add
another language, set the `recording_studio.lists` keys in the host's
`config/locales`.

## Current Requirements

- Ruby 3.3 or newer
- Rails 8.1 or newer
- Recording Studio 4.x (`~> 4.2` in the gemspec; dummy GitHub tag `v4.4.0`)
- Accessible dummy tag `v0.9.1` and Root Switchable dummy tag `v0.5.0`
- FlatPack dummy tag `v0.1.177`
- Public RubyGems and GitHub access for dependency installation

## Verification

Install both bundles and run the complete gem and dummy app test path:

```bash
bundle install
BUNDLE_GEMFILE=test/dummy/Gemfile bundle install
bundle exec rake test:all
```

Run the dummy app from its directory for browser verification:

```bash
cd test/dummy
bin/dev
```

Use the [FlatPack repository](https://github.com/bowerbird-app/flatpack) and the live FlatPack demo linked from the top-level README for current component documentation.
