# Migration Notes

## Upgrading To 0.5.0

This is a non-breaking upgrade for English hosts. Rendered English interface
text, flash notices, and error messages stay byte-identical to 0.4.0 / main.

### What Changed

- Controller flashes, blank-name form errors, and `RecordingStudio::Lists::*`
  exception defaults resolve through Rails I18n under `recording_studio.lists`
  with English `default:` values.
- Public error `MESSAGE` constants and recordable `LABEL` / `PLURAL_LABEL`
  constants remain the English literals (public API). Call-time helpers
  (`Copy.t`, `recordable_type_label`, exception `#message` with no override)
  follow the active locale.
- Add-to-list Stimulus errors use `data-blank-name` and `data-save-failed` on
  the create form; JS keeps English fallbacks if those attributes are absent.
- Recordable labels `List` / `List item` / `List items` stay on
  `recording_studio_recordable` as English (class-load DSL) and also ship as
  pluralized `recording_studio.lists.recordables.*.label` keys for call-time
  `recordable_type_label` / `recordable_type_plural_label`.

Left untranslated on purpose: list names and descriptions (user data),
generator CLI text, developer-facing ArgumentErrors / logs, icon/style tokens,
and the add-to-list row template placeholder `Name` (replaced by JavaScript
when a list is created). Admin column headers stay English (none ship here).

This gem never shipped a top-level `recording_studio_lists.*` locale
namespace. Host overrides belong under `recording_studio.lists`.

### Upgrade Steps

No migration is required. English hosts need no change. To override or add
another language, set the `recording_studio.lists` keys in the host's
`config/locales`. Prefer call-time label helpers over comparing against
`LABEL` / `PLURAL_LABEL` when the locale may not be English.

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

This gem never shipped a top-level `recording_studio_lists.*` locale
namespace. There is nothing to deprecate or keep in parallel. Host overrides
belong under `recording_studio.lists`.

### Upgrade Steps

No migration is required. English hosts need no change. To override or add
another language, set the `recording_studio.lists` keys in the host's
`config/locales`.

## Current Requirements

- Ruby 3.3 or newer
- Rails 8.1 or newer
- Recording Studio 4.x (`~> 4.2` in the gemspec; dummy GitHub tag `v4.5.0`)
- Accessible dummy tag `v0.15.0`, Root Switchable dummy tag `v0.8.0`, and Metrics dummy tag `v0.2.0`
- FlatPack dummy tag `v0.1.196`
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
