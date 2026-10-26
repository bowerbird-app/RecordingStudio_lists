# Migration Notes

## Upgrading To 0.9.0

No migration is needed.

### What Changed

- List screens use `recording_studio/default_layout` unless you set a layout.
- `RecordingStudioLists.configuration.layout` is checked first. `nil` uses `RecordingStudio.configuration.layout`, then `"recording_studio/default_layout"`.
- Accepted values are `nil`, `false`, a layout name, and a callable that takes `controller:` as a keyword. `false` skips the layout. A blank name or a positional callable raises `ArgumentError`.
- The lists controller no longer includes `RecordingStudio::UsesDefaultLayout`.
- Page titles come from `content_for(:title)` and `content_for(:subtitle)`. Do not also render `FlatPack::PageTitle` on these screens.
- Delete list is an Actions menu on each index row. The menu item says Delete list and posts to the list. Edit list sits above it and opens the edit form. The list page does not render a delete control. Item remove stays on the row. A member name is a link when the host can route that recordable or recording. Otherwise the name is plain text.
- The new-list button sits in the page body, under the title. The index does not call `register_page_nav` for it.
- `RecordingStudio::Lists.update(list, name:, description: nil, actor: nil)` revises the list. The recording id stays. A new list snapshot and an `updated` event are stored. A blank name raises `BlankName` and writes nothing. A missing list or another recordable raises `InvalidList`. Omit `description`, or pass a blank one, and the description is cleared.
- Requires Recording Studio `~> 6.1` (development pin `v6.1.0`) and Flatpack `>= 0.1.315` (development pin `v0.1.315`).
- Filled list index and show use `FlatPack::Card` with `border: :default`. A host that compiles Tailwind must scan the installed Flatpack gem so `border`, the card background, the card padding, and the card radius utilities are in the built CSS. The rounded theme's theme border width is 0, so leaving the card border unset draws no edge.

### Upgrade Steps

No migration is required. Pin Recording Studio `~> 6.1` and Flatpack `>= 0.1.315`. Set `config.layout` only when the default cascade is wrong.

```ruby
RecordingStudioLists.configure do |config|
  config.layout = "application"
end
```

Published Orderable, Accessible, Trashable, Root Switchable, Metrics, and Cache tags still require Recording Studio below 5. This gem's development Gemfiles widen that requirement while Bundler loads gemspecs. The dummy app defines `RecordingStudio::UsesDefaultLayout` so Orderable and Trashable can eager-load. List screens and the host controller do not include it. Host apps need addon releases that allow Recording Studio 6.1.0 before they can install this version next to those tags.

## Upgrading To 0.8.0

No migration is needed.

### What Changed

- `recording_studio_add_to_list` accepts `icon_only:` and `round:`.
- A blank `text:` on an icon-only trigger uses
  `recording_studio.lists.add_to_list.icon_only`.
- `show_chevron` is omitted unless the caller sets it. Dropdown then shows the
  chevron on a labeled trigger and hides it on an icon-only trigger.

### Upgrade Steps

No migration is required. A labeled trigger keeps its markup. Hosts that pass
`icon_only:` or `round:` need Flatpack >= 0.1.276.

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
- A plain `default:` with no interpolation is returned as a plain
  (non-html_safe) String, so views will escape it. Interpolating caller
  `default:` on a missing `_html` key is stricter than view `t` (args escaped,
  result html_safe).

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
- Recording Studio `~> 6.1` (gemspec; development GitHub tag `v6.1.0`)
- Orderable `~> 0.3` (dummy GitHub tag `v0.3.1`)
- Accessible dummy tag `v0.18.0`, Trashable dummy tag `v0.11.0` (`require: false`), Root Switchable dummy tag `v0.9.0`, Metrics dummy tag `v0.2.0`, and Cache dummy tag `v0.5.0`
- Flatpack development tag `v0.1.315`
- Published sibling tags still require Recording Studio below 5. The development Gemfiles widen that requirement at resolve time. Hosts need addon releases that allow 6.1.0.
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
