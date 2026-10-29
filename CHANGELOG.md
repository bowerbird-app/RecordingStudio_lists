# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.9.2] - 2026-10-28

### Changed

* Stop tracking SimpleCov output under `coverage/` and `test/dummy/coverage/`; both directories are gitignored.
* Docs match the current pins and install generator: development Flatpack tag `v0.1.329`, no `flat_pack` gemspec dependency, default engine mount `/recording_studio_lists`.

### Upgrade notes

- No migration is required.
- No host code change is required. Ignore SimpleCov HTML under `coverage/` if it was checked out from an older tree.

## [0.9.1] - 2026-10-28

### Changed

* Development apps pin Flatpack `v0.1.329`. The dummy app no longer prepends PageNav or Card shims. Native PageNav is `with_link`, `with_back`, `with_close`, `with_action`, and `with_item`. Card takes `background`, `border`, `shadow`, `hover`, `padding`, `inset`, and `radius`, not `style:`. List screens already used `flat_pack_page_nav(back_href:, back_tooltip:)` and `border: :default` on filled cards.
* Dummy/dev sibling pins align with the resolving set: Root Switchable `v0.10.0`, Cache `v0.5.1`, Accessible `v0.21.0`, Metrics `v0.6.1`, Trashable `v0.11.3` (`require: false`). Recording Studio stays `v6.1.0`.
* Dummy lockfile updates `net-ssh` `7.3.0` → `7.3.8` (advisory floor `>= 7.3.5`).

### Upgrade notes

- No migration is required.
- Dummy and development Gemfiles pin Flatpack tag `v0.1.329`. Delete dummy PageNav and Card prepends that mapped `anchor_url` / `anchor_label` and dropped `style:`. Hosts that still compile against Flatpack `0.1.315` can keep that pin; this gem still has no `flat_pack` gemspec dependency.

## [0.9.0] - 2026-10-26

### Added

* `RecordingStudio::Lists.update` revises a list name and description. The recording id stays, a new list snapshot is stored, and Recording Studio records an `updated` event. A blank name raises `BlankName`. A missing list or another recordable raises `InvalidList`.
* The lists index Actions menu includes Edit list. The edit screen patches the list.

### Changed

* List screens use the Recording Studio 6.1 default layout. The title and subtitle come from `content_for`. Back uses `flat_pack_page_nav`. The new-list button sits in the page body under the title. It is not registered in the page nav.
* Delete list is an Actions menu on each index row. The menu item says Delete list, uses the trash icon, and posts `method: :delete`. The list page does not show a delete control. A member name is a link when the host can route the recordable or the recording, and plain text otherwise.
* An empty list show page uses `FlatPack::EmptyState`. The item card sits in the two-column grid only when the list has items.
* A filled list index and show pass `border: :default` on `FlatPack::Card`. Flatpack's nil border uses the theme width, and the rounded theme sets that width to 0.
* The dummy Tailwind build scans installed `flatpack-<rev>` and `RecordingStudio-<rev>` checkouts (`app/components`, `app/helpers`, and Recording Studio `app/views`) under `vendor/bundle`, `/usr/local/bundle`, and the system gem home.
* `RecordingStudioLists.configuration.layout` accepts `nil`, `false`, a layout name, or a callable with the keyword `controller:`. `nil` uses `RecordingStudio.configuration.layout`, then `"recording_studio/default_layout"`.
* Require Recording Studio `~> 6.1`. The development apps pin tag `v6.1.0`, Flatpack `v0.1.315`, and `view_component` `4.19.0`. Minitest stays below 6 so the suite keeps `stub`.
* Development Ruby pin is `3.3.13`. The gem still requires Ruby `>= 3.3.0`. GitHub `ubuntu-latest` only installs the latest 3.3 patch.

### Removed

* `RecordingStudio::UsesDefaultLayout` on the lists controller. Recording Studio 5.0 removed that module.
* Inline `FlatPack::PageTitle` on the list index, show, and new screens, so the layout renders the only `h1`.

### Upgrade notes

- No migration is required.
- Pin Recording Studio `~> 6.1` and Flatpack `>= 0.1.315`.
- Set `RecordingStudioLists.configuration.layout` when list screens should not use the core layout. See [MIGRATION_NOTES.md](MIGRATION_NOTES.md#upgrading-to-090).
- Delete list is the Actions menu on the lists index. Edit list is the item above it. The list page no longer shows a delete control in the top-right.
- The new-list button is in the page body, under the title. It is no longer registered with `register_page_nav`.
- Filled list cards use `border: :default`. Rebuild Tailwind so the Flatpack card border, background, padding, and radius utilities are in the host CSS.
- Published Orderable, Accessible, Trashable, Root Switchable, Metrics, and Cache tags still require Recording Studio below 5. An app that uses those tags cannot resolve this gem until those addons allow 6.1.0.

## [0.8.0] - 2026-10-20

### Added

* `recording_studio_add_to_list` accepts `icon_only:` and `round:` and passes
  them to `FlatPack::Button::Dropdown`. Both default to `false`.
* Shipped English `recording_studio.lists.add_to_list.icon_only` ("Add to list")
  is the accessible name when an icon-only trigger's `text:` is blank.

### Changed

* `show_chevron` no longer defaults to `true`. When you omit it, Dropdown shows
  the chevron on a labeled trigger and hides it on an icon-only trigger.
  `icon_only: true` with `show_chevron: true` raises `ArgumentError`.
* Development app pins Flatpack `v0.1.276` and Recording Studio `v4.7.1`.
  Recording Studio 4.7.1 builds page nav with `with_back`, `with_close`, and
  `with_item`. Flatpack 0.1.274 removed the old PageNav keywords.

### Upgrade notes

- No migration is required. A labeled trigger renders the same markup.
- Hosts that pass `icon_only:` or `round:` need Flatpack >= 0.1.276.
- See [MIGRATION_NOTES.md](MIGRATION_NOTES.md#upgrading-to-080).

## [0.7.0] - 2026-10-14

### Added

* English fallback for shipped `recording_studio.lists.*` keys when the active
  locale has no translation: call sites use `RecordingStudio.t` /
  `RecordingStudioLists::Copy.t`, and the engine registers
  `config/locales/en.yml` via
  `RecordingStudio::Translation.register_shipped_english` at boot (before
  `recording_studio.load_shipped_english`). Fallback comes from the loaded
  English, host overrides included, then the caller's `default:`, then the
  merged gem-shipped table.
* Require Recording Studio `~> 4.7` (root and dummy GitHub pin `v4.7.0`)

### Changed

* View, helper, and controller copy lookups drop hand-copied English
  `default:` values that matched `en.yml`; English still comes from the gem
  locale file / loaded `:en` backend
* `RecordingStudioLists::Copy.t` routes through `RecordingStudio.t`

### Upgrade notes

- No migration or host code change is required for English.
- Pin Recording Studio `~> 4.7`. Addon engines that ship
  `recording_studio.lists.*` English rely on
  `RecordingStudio::Translation.register_shipped_english` so keys remain
  available after the loaded `:en` backend is pruned.
- Fallback comes from the loaded English, host overrides included.
- Only this gem's `recording_studio.lists.*` keys use `RecordingStudio.t`;
  host or other-namespace keys stay on `I18n.t` with main's `default:`.
- A plain `default:` with no interpolation is returned as a plain
  (non-html_safe) String, so views will escape it. Interpolating caller
  `default:` on a missing `_html` key is stricter than main/view `t` (args
  escaped, result html_safe).
- See [MIGRATION_NOTES.md](MIGRATION_NOTES.md#upgrading-to-070).

## [0.6.0] - 2026-10-14

### Changed

* List item order now uses Recording Studio Orderable. `RecordingStudio::Lists::List`
  opts into `RecordingStudio::Capabilities::Orderable.to(allows: ["RecordingStudio::Lists::ListItem"])`.
  Membership order is stored on `recording_studio_recordings.recording_studio_orderable_position`
  instead of a lists-owned `position` column on `recording_studio_list_items`.
* `RecordingStudio::Lists.items` reads through `recording_studio_orderable_children`.
  `RecordingStudio::Lists.add` writes `max + 1` onto Orderable storage only — it does
  not call `recording_studio_orderable_append!` / reorder, so it does not renumber
  siblings, log a `reordered` event, or run Orderable's reorder access check (same
  as main's membership add).
* Gemspec depends on `recording_studio_orderable`, `~> 0.3`. Root and dummy Gemfiles
  pin GitHub tag `v0.3.1`.

### Removed

* `recording_studio_list_items.position` and check constraint
  `recording_studio_list_items_position_check` (migrated away for existing hosts;
  omitted from the create migration for new installs).

### Upgrade notes

- Add `recording_studio_orderable` (GitHub tag `v0.3.1` or compatible `~> 0.3`).
- Run `bin/rails generate recording_studio_orderable:migrations` and migrate so
  `recording_studio_orderable_position` exists before the lists data migration.
- Run `bin/rails generate recording_studio_lists:migrations` then `bin/rails db:migrate`.
  The data migration backfills each list-item recording with a per-parent
  `ROW_NUMBER()` ordered by `COALESCE(position, 0), recording id` (main's read
  order, including ties and nulls), then drops the lists-owned column and check
  constraint. `down` restores the column and renumbers each list to contiguous
  1-based positions from the current Orderable order.
- Public `RecordingStudio::Lists` call sites are unchanged. Hosts that call
  `recordable.position` on list items must switch to Orderable
  (`recording.recording_studio_orderable_position` or
  `list.recording_studio_orderable_children`).
- See [MIGRATION_NOTES.md](MIGRATION_NOTES.md#upgrading-to-060).

## [0.5.0] - 2026-10-12

### Added

* English Rails I18n keys for controller flashes, error messages, JS client
  strings, and recordable label catalog keys under `recording_studio.lists`
  (`flashes.*`, `errors.*`, `js.*`, `recordables.*`)
* Always-loaded dummy host override
  `test/dummy/config/locales/recording_studio_lists_host.en.yml` on the rarely
  shown `index.home` key (lists page-nav back label)
* Locale regression: every `lib/**/*.rb` file must not mention
  `i18n.load_path` / `I18n.load_path`
* Record Recording Studio GitHub pin `v4.4.0` (root and dummy Gemfiles; the
  unreleased pin bullet was dropped when 0.4.0 shipped)
* Record Recording Studio GitHub pin `v4.5.0` (root and dummy Gemfiles; core
  i18n wave 2)

### Changed

* Controller flash/notice/alert copy resolves through
  `RecordingStudioLists::Copy.t(..., default: <main English>)` at the render
  site (English output unchanged)
* List error alerts / JSON / blank-name form errors translate at the controller
  render site by exception class (`default: error.message`); the missing-root
  path still raises `ParentNotAllowed` with main's literal
  `"Choose a place for this list first."` and swaps that literal at the flash
  site
* Public error classes keep main's literal English default messages (no new
  exception types; no unused `MESSAGE` constants)
* Add-to-list helper keeps main's `text: I18n.t("recording_studio.lists.add_to_list.trigger")`
  and adds English `default: "Add to list"`
* Add-to-list Stimulus client errors read `data-blank-name` /
  `data-save-failed` from the create form, with English fallbacks in JS
* View `t(...)` calls pass English `default:` values

### Upgrade notes

- No migration or host code change is required for English.
- To translate or override the new defaults, add keys under
  `recording_studio.lists.flashes`, `errors`, `js`, and `recordables` in the
  host's locale files.
- Public model / helper defaults stay English. Translate at your render call
  sites (or rely on the gem's controller / partial sites).
- `recording_studio_add_to_list` still defaults `text:` to `"Add to list"`.
  Pass your own `text: t(...)` when the host label should follow the locale.
- See [MIGRATION_NOTES.md](MIGRATION_NOTES.md#upgrading-to-050).

## [0.4.0] - 2026-10-09

### Added

* English Rails I18n keys for static interface copy in the gem's own lists
  screens and add-to-list helper (`config/locales/en.yml` under
  `recording_studio.lists`)

### Changed

* Index, new, show, and add-to-list view copy resolve through `t(...)`
  (English output unchanged)

### Upgrade notes

- No migration or host code change is required for English.
- To translate or override the defaults, add keys under
  `recording_studio.lists` in the host's locale files.
- See [MIGRATION_NOTES.md](MIGRATION_NOTES.md#upgrading-to-040).

## [0.3.0] - 2026-09-29

### Added
- List and list item recordables. Membership is a child recording that points at an existing recording.
- `RecordingStudio::Lists` for create, add, remove, items, lists, find, addable, and delete.
- Index, new, and show screens mounted with the engine.
- `recording_studio_add_to_list` renders a menu of list names. A check sits to the right of lists that already hold the recording, so the name stays put. Choosing a name adds or removes it and the check follows. `icon:` takes any heroicon, `text: ""` leaves the label off, and `show_chevron: false` hides the arrow. List opens a name field in the menu. Saving creates the list and adds the recording there.

### Upgrade notes
- Register `RecordingStudio::Lists::List` and `RecordingStudio::Lists::ListItem`.
- Enable `:lists` on the host root type.
- Run `bin/rails generate recording_studio_lists:migrations`, then `bin/rails db:migrate`.
- Mount `RecordingStudioLists::Engine` after the host routes.

## 0.2.2 - 2026-09-11

### Changed
- Gemspec `recording_studio` floor `~> 4.1` → `~> 4.2` so copied addons match Accessible 0.7+.
- Dummy Accessible tag `v0.6.0` → `v0.9.1`; FlatPack tag `v0.1.133` → `v0.1.177`. Recording Studio stays `v4.2.0`; Root Switchable stays `v0.5.0`.
- Root `Gemfile.lock` Rails `8.1.1` → `8.1.3.1` (with `json` `2.21.2`, `mail` `2.9.1`, `nokogiri` `1.19.4`) to match the dummy host lock and Active Storage CVE-2026-66066.
- Extra Cloud Agent skills now come from the plugin catalog (`skill-sources.json`) instead of a hardcoded extra URL. A missing or invalid catalog is skipped so Recording Studio skills still fetch. Failures still warn and exit 0.
- Docs and pin tests no longer mention `recording_studio/v3.0.0`, FlatPack `v0.1.133`, or Accessible `v0.6.0`.

### Added
- After skills, the Cloud Agent fetch hook lists plugin `*.mdc` rules from `RecordingStudio_cursor_plugin` into `.cursor/rules/` (gitignored, not packaged). A missing rules directory warns and skips. Failures still exit 0.
- Cloud Agent skill-fetch hook so copied addons load Recording Studio skills at Build time. `.cursor/environment.json` names the environment `recording-studio-gem-template`. `install` is `.cursor/install.sh`, which runs `.cursor/fetch-skills.sh` after provisioning. `snapshot` is omitted on purpose so Builds run install instead of reusing a laptop Personal snapshot. The script lists `recording-studio-*` skill ids from the public GitHub contents API and writes each `SKILL.md` into `.cursor/skills/` (gitignored, not packaged). Failures warn and still exit 0.
- Dummy Accessible migration for `depends_on_recording_id` (Accessible 0.8+).

### Upgrade notes
- Bump addon gemspecs to `spec.add_dependency "recording_studio", "~> 4.2"`.
- Point host/dummy Gemfiles at Accessible `v0.9.1` and FlatPack `v0.1.177` (Recording Studio tag stays `v4.2.0`).
- Run `bin/rails generate recording_studio_accessible:migrations` then `bin/rails db:migrate`. Do not hand-edit Accessible tables.
- Rebuild Tailwind after the FlatPack tag bump: `bin/rails tailwindcss:build`.
- Align root gem-suite `Gemfile.lock` Rails to `8.1.3.1` if it is still on `8.1.1`.

## 0.2.1 - 2026-09-01

### Added
- Full Cloud Agent development environment. `.cursor/install.sh` now provisions the whole stack at Build time on Cursor's default image — Ruby (pinned by `.ruby-version`), PostgreSQL 16, gem dependencies for both the gem and the dummy host app, the seeded dummy database, and compiled Tailwind/FlatPack CSS — then runs the existing `.cursor/fetch-skills.sh`. `snapshot` stays omitted so Builds run `install` as before.
- `.cursor/start.sh` per-boot hook that starts PostgreSQL and waits for readiness.
- `.cursor/environment.json` now declares `start` plus `rails-server` and `tailwind-watch` terminals and exposes port 3000, so a fresh Cloud Agent boots straight into a running, signed-in-ready dummy app.

### Notes
- The install script is idempotent; running it against a warm machine reuses the existing Ruby, packages, and gems.
- No gem runtime code changed. `.cursor/` files are excluded from the packaged gem.

## 0.2.0 - 2026-08-21

New addons copied from this template are born on Recording Studio 4.x.

### Added
- Gemspec dependency `recording_studio`, `~> 4.1`
- Dummy host wiring for Accessible (`enable_capability(:accessible, on: Workspace)`) and an opt-in `RecordingStudio::Capabilities::Example.to` mixin. `.to` wraps core 4.2.0 `include_for` (not a fourth verb, and not a raw `enable_capability` / `set_capability_options` path). Installing the gem does not enable the mixin globally; only dummy Workspace opts in.
- `bin/rename_gem` leftover-identity rewrite/verification for README, homepage, and changelog URLs that still say `RecordingStudioLists` or point at `bowerbird-app/recording_studio_lists`

### Changed
- Dummy GitHub tags: Recording Studio `v4.2.0`, Accessible `v0.6.0`, Root Switchable `v0.5.0`, FlatPack `v0.1.133`
- Dummy authenticated layout is Recording Studio's default layout plus FlatPack CSS/JS; Devise keeps its own sign-in layout
- Dummy app security pins: Rails `8.1.3.1`, `json` `2.21.2`, `mail` `2.9.1`, Brakeman `8.0.6`
- Require `RecordingStudio::Hooks` and `RecordingStudio::Services::BaseService` from core instead of shipping copies

### Removed
- Copied `lib/recording_studio_lists/hooks.rb` and `lib/recording_studio_lists/services/base_service.rb`
- Product-shipped `ExampleService`
- Custom `flat_pack_sidebar` authenticated shell

### Upgrade notes
- Point dummy or host Gemfiles at Recording Studio `v4.2.0` (not `recording_studio/v3.0.0`)
- Add `spec.add_dependency "recording_studio", "~> 4.1"` to addon gemspecs
- Include `RecordingStudio::UsesDefaultLayout` (or set `layout "recording_studio/default_layout"`) for authenticated screens
- Delete any copied Hooks or BaseService files and require the core classes
- Keep recordable declarations; they are required, not a v3-only concern
- If Accessible is bundled, call `RecordingStudio.enable_capability(:accessible, on: Workspace)` (or your root type)

## 0.1.2 - 2026-07-21

### Changed
- Bumped the dummy app FlatPack dependency from `v0.1.33` to `v0.1.129`

## 0.1.1 - 2026-04-28

### Changed
- Bumped the dummy app FlatPack dependency from `0.1.2` to `0.1.33` and pinned it by tag in `test/dummy/Gemfile`

## 0.1.0 - 2025-12-04

### Added
- Initial release
- Rails mountable engine structure
- PostgreSQL with UUID primary keys support
- TailwindCSS v4 integration
- GitHub Codespaces devcontainer configuration
- Docker Compose setup with PostgreSQL and Redis
- Install generator for host applications
- Comprehensive README and documentation
- Basic test suite with Minitest

[Unreleased]: https://github.com/bowerbird-app/RecordingStudio_lists/compare/v0.9.2...HEAD
[0.9.2]: https://github.com/bowerbird-app/RecordingStudio_lists/compare/v0.9.1...v0.9.2
[0.9.1]: https://github.com/bowerbird-app/RecordingStudio_lists/compare/v0.9.0...v0.9.1
[0.9.0]: https://github.com/bowerbird-app/RecordingStudio_lists/compare/v0.8.0...v0.9.0
[0.8.0]: https://github.com/bowerbird-app/RecordingStudio_lists/compare/v0.7.0...v0.8.0
[0.7.0]: https://github.com/bowerbird-app/RecordingStudio_lists/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/bowerbird-app/RecordingStudio_lists/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/bowerbird-app/RecordingStudio_lists/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/bowerbird-app/RecordingStudio_lists/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/bowerbird-app/RecordingStudio_lists/releases/tag/v0.3.0
