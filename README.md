# Recording Studio Lists

A list is a child recording under a parent you choose. Each member is a list item recording that points at another recording in the same tree.

## Mount

Add `recording_studio_lists` and `recording_studio_orderable` to the host Gemfile.
Orderable owns sibling position on recordings; lists opts `List` into that capability
for `ListItem` children. Copy both engines' migrations and migrate Orderable first.

```bash
bin/rails generate recording_studio_orderable:migrations
bin/rails generate recording_studio_lists:migrations
bin/rails db:migrate
```

The install generator mounts the engine at `/recording_studio_lists` so `/` stays the host home. Pass `--mount-path` to change that prefix.

```ruby
mount RecordingStudioLists::Engine, at: "/recording_studio_lists"
```

The screens are `/recording_studio_lists/lists`, `/recording_studio_lists/lists/new`, `/recording_studio_lists/lists/:id`, and `/recording_studio_lists/lists/:id/edit`. The dummy app mounts at `/` for its own screens.

## Enable

Register both recordable types in the host initializer. Enable `:lists` on the host root type. The dummy app enables it on Workspace.

Dummy credentials (`test/dummy/config/credentials.yml.enc`) are encrypted with the shared RecordingStudio_* development master key. Set `RAILS_MASTER_KEY` or put that key in `test/dummy/config/master.key` (gitignored). Keep the encrypted file; do not generate a per-repo dummy key.

```ruby
config.recordable_types = [
  "Workspace",
  "Folder",
  "Page",
  "RecordingStudio::Lists::List",
  "RecordingStudio::Lists::ListItem"
]

RecordingStudio.enable_capability(:lists, on: Workspace)
```

`RecordingStudio::Lists::List` already includes Orderable for its list-item
children. Hosts do not enable `:orderable` separately for lists.

`RecordingStudio::Lists.add` writes the next Orderable position (`max + 1`) and
does not call Orderable `append!` / reorder. Membership add therefore does not
renumber siblings, log a `reordered` event, or run Orderable's reorder access
check — same as main.

## Ruby

```ruby
list = RecordingStudio::Lists.create(parent: parent, name: "Reading", description: "Magazines")
RecordingStudio::Lists.update(list, name: "Edited", description: "Notes", actor: actor)
RecordingStudio::Lists.add(list, page)
RecordingStudio::Lists.items(list)
RecordingStudio::Lists.remove(list, page)
RecordingStudio::Lists.lists(parent)
RecordingStudio::Lists.addable(list)
RecordingStudio::Lists.find(list.id)
RecordingStudio::Lists.delete(list)
```

`create` accepts `idempotency_key` and `actor`. `add` and `update` accept `actor`. Pass a recording or its id.

`update` requires a list recording. A missing list, or any other recordable, raises `InvalidList`. A blank name raises `BlankName` and writes nothing. Surrounding spaces are removed from the name. A blank `description` is stored as `nil`. If you omit `description`, the description is cleared. The recording id stays the same. Recording Studio stores a new list snapshot and an `updated` event.

## Screens

The index lists names. A List button under the title opens the new-list form. Each row has an Actions menu. Edit list opens the edit form. Delete list deletes the list. New list and edit list ask for a name and an optional description. The list page removes a member. A member name is a link when the host can route that record, and plain text otherwise.

Static interface copy on these screens (and the add-to-list menu), controller flashes, error messages, and JS client strings resolve through `RecordingStudio.t` under `recording_studio.lists` at the render site. When the active locale has no value, fallback comes from the loaded English (host overrides included), then a caller `default:`, then the gem-shipped `config/locales/en.yml` registered at boot. Only this gem’s `recording_studio.lists.*` keys use `RecordingStudio.t`; host or other-namespace keys stay on `I18n.t` with their original `default:`. A plain `default:` with no interpolation is returned as a plain (non-html_safe) String, so views will escape it. Interpolating caller `default:` on a missing `_html` key is stricter than view `t` (args escaped, result html_safe). Public model defaults stay English. Hosts can override or translate those keys; there is no dependency on `recording_studio_internationalization`. Requires Recording Studio `~> 6.1`. This gem has no `flat_pack` gemspec dependency. Development apps pin Flatpack `v0.1.331`. Recording Studio 6.1 itself requires `flat_pack >= 0.1.315`.

## Layout

`RecordingStudioLists.configuration.layout` chooses the layout for list screens.

Leave it `nil` to use `RecordingStudio.configuration.layout`, then `"recording_studio/default_layout"`. Set `false` to render with no layout. Set a layout name to force that layout. Set a callable when the layout depends on the request. The callable must take `controller:` as a keyword. A blank name or a positional callable raises `ArgumentError`.

```ruby
RecordingStudioLists.configure do |config|
  config.layout = "application"
end
```

The default layout draws the title and subtitle from `content_for`. List screens do not render a second page title. The List button sits in the page body, under the title. Each list row has an Actions menu. Edit list links to the edit form. Delete list posts to the list. The list page does not show a delete control. Item remove stays on the row.

## Add to a list

`recording_studio_add_to_list` drops a menu on any page that already has a recording. It is not part of the list screens.

```erb
<%= recording_studio_add_to_list(page) %>
<%= recording_studio_add_to_list(page, icon: "heart", icon_only: true, round: true) %>
```

The menu lists names under the current root. A check sits to the right of a name when the recording is already on that list, so the name stays put. Choosing a name without a check adds it and the check appears. Choosing a checked name removes it and the check goes away. The page stays put. List opens a name field in the menu. Saving creates the list, adds the recording, and checks the new name. The lists page still uses the new-list form when a description is needed.

Pass `text:`, `icon:`, `icon_only:`, `round:`, `style:`, `size:`, `show_chevron:`, `placement:`, `parent:`, or `return_to:` when the defaults are wrong. `text: ""` leaves the label off a labeled trigger. `icon:` is any heroicon name. Omit `show_chevron:` to keep the arrow on a labeled trigger and hide it on an icon-only trigger. `show_chevron: false` hides the arrow. `icon_only: true` with `show_chevron: true` raises `ArgumentError`. `round: true` draws a circle. `round:` must be `true` or `false`. An icon-only trigger with a blank `text:` uses `recording_studio.lists.add_to_list.icon_only` ("Add to list") as its accessible name. A non-blank `text:` is that name instead. `parent:` defaults to the current root. Hosts using the add-to-list menu need a Flatpack that ships `FlatPack::Button::Dropdown` host hooks (`menu_class:`, `menu_attributes:`, `icon_position:`, `keep_open:`, `menu_form`) plus `icon_only:` and `round:` (development pin `v0.1.331`).
