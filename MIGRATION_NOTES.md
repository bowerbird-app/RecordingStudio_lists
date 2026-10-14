# Migration Notes

## Upgrading To 0.7.0

This is a non-breaking upgrade for English hosts. Rendered English interface
text, flash notices, and error messages stay byte-identical to 0.6.0 / main.

### What Changed

- Call sites use `RecordingStudio.t` / `RecordingStudioLists::Copy.t` instead of
  plain `t` / `I18n.t` with hand-copied English `default:` values.
- The engine registers `config/locales/en.yml` with
  `RecordingStudio::Translation.register_shipped_english` at boot so missing
  active-locale keys still show gem English after the loaded `:en` backend is
  pruned.
- Requires Recording Studio `~> 4.7` (dummy pin `v4.7.0`).
- Fallback comes from the loaded English, host overrides included.
- Only this gem's `recording_studio.lists.*` keys use `RecordingStudio.t`;
  host or other-namespace keys stay on `I18n.t` with main's `default:`.
- Interpolating caller `default:` on a missing `_html` key is stricter than
  view `t` (args escaped, result html_safe). Non-interpolating caller defaults
  on a missing `_html` key stay unsafe like view `t`.

### Upgrade Steps

No migration is required. English hosts need no change beyond pinning
Recording Studio `~> 4.7`. Host overrides still belong under
`recording_studio.lists` in the host's `config/locales`.

## Upgrading To 0.6.0

List item order moves from a lists-owned `position` column to Recording Studio
Orderable on the child recording.

### What Changed

- `RecordingStudio::Lists::List` includes
  `RecordingStudio::Capabilities::Orderable.to(allows: ["RecordingStudio::Lists::ListItem"])`.
- `RecordingStudio::Lists.add` writes `max + 1` onto
  `recording_studio_orderable_position` only. It does not call Orderable
  `append!` / reorder, so it does not renumber siblings, log `reordered`, or
  enforce Orderable's reorder access check (same as main).
- `RecordingStudio::Lists.items` (and internal membership reads) use
  `recording_studio_orderable_children`.
- `recording_studio_list_items.position` and
  `recording_studio_list_items_position_check` are removed.

### Data Migration And Rollback

Migration `MoveListItemPositionsToOrderable`:

1. Requires `recording_studio_recordings.recording_studio_orderable_position`
   (install Orderable migrations first).
2. **up:** per parent, set `recording_studio_orderable_position` to
   `ROW_NUMBER()` ordered by `COALESCE(list_items.position, 0), recordings.id`
   (main's read order for ties and nulls), then drop the check constraint and
   `position` column.
3. **down:** re-add `position` (nullable), renumber each list's items to
   contiguous 1-based `position` values from the current Orderable order
   (`ROW_NUMBER` by `recording_studio_orderable_position`, `created_at`, `id`),
   set any remaining nulls to `1`, make the column non-null, and restore
   `recording_studio_list_items_position_check` (`position >= 1`). Exact
   integers may differ from pre-upgrade values; relative order is preserved.

### Upgrade Steps

1. Add `recording_studio_orderable` (`~> 0.3`; GitHub tag `v0.3.1`).
2. `bin/rails generate recording_studio_orderable:migrations`
3. `bin/rails generate recording_studio_lists:migrations`
4. `bin/rails db:migrate`
5. Stop reading `list_item.position`; use Orderable on the recording instead.

Public `RecordingStudio::Lists` methods keep the same signatures and return
membership in the same order.

## Upgrading To 0.5.0

This is a non-breaking upgrade for English hosts. Rendered English interface
text, flash notices, and error messages stay byte-identical to 0.4.0 / main.

### What Changed

- Controller flashes and list error alerts / JSON / blank-name form errors
  resolve through Rails I18n under `recording_studio.lists` at the render site,
  with English `default:` values.
- Public error classes keep main's literal English default messages.
  `#message` stays English; the controller maps exception class → locale key.
  The missing-root path still raises `ParentNotAllowed` with main's literal
  `"Choose a place for this list first."` and swaps that literal at the flash
  site.
- `recording_studio_add_to_list` keeps main's
  `text: I18n.t("recording_studio.lists.add_to_list.trigger")` and adds
  English `default: "Add to list"`. Pass `text:` from the host when needed.
- Add-to-list Stimulus errors use `data-blank-name` and `data-save-failed` on
  the create form; JS keeps English fallbacks if those attributes are absent.
- Recordable labels stay English on `recording_studio_recordable` (class-load
  DSL). Catalog keys under `recording_studio.lists.recordables.*` are available
  for host render sites; the gem does not translate inside model methods.

Left untranslated on purpose: list names and descriptions (user data),
generator CLI text, developer-facing ArgumentErrors / logs, icon/style tokens,
and the add-to-list row template placeholder `Name` (replaced by JavaScript
when a list is created). Admin column headers stay English (none ship here).

This gem never shipped a top-level `recording_studio_lists.*` locale
namespace. Host overrides belong under `recording_studio.lists`.

### Upgrade Steps

No migration is required. English hosts need no change. To override or add
another language, set the `recording_studio.lists` keys in the host's
`config/locales`. Translate at render call sites.

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
- Recording Studio `~> 4.7` (gemspec; dummy GitHub tag `v4.7.0`)
- Orderable `~> 0.3` (dummy GitHub tag `v0.3.1`)
- Accessible dummy tag `v0.18.0`, Trashable dummy tag `v0.10.0` (`require: false`), Root Switchable dummy tag `v0.9.0`, Metrics dummy tag `v0.2.0`, and Cache dummy tag `v0.5.0`
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
