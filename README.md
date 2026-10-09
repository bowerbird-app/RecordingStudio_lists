# Recording Studio Lists

A list is a child recording under a parent you choose. Each member is a list item recording that points at another recording in the same tree.

## Mount

Add `recording_studio_lists` to the host Gemfile. Copy the migrations and migrate.

```bash
bin/rails generate recording_studio_lists:migrations
bin/rails db:migrate
```

Mount the engine after the host routes so `/` stays the host home.

```ruby
mount RecordingStudioLists::Engine, at: "/"
```

The screens are `/lists`, `/lists/new`, and `/lists/:id`.

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

## Ruby

```ruby
list = RecordingStudio::Lists.create(parent: parent, name: "Reading", description: "Magazines")
RecordingStudio::Lists.add(list, page)
RecordingStudio::Lists.items(list)
RecordingStudio::Lists.remove(list, page)
RecordingStudio::Lists.lists(parent)
RecordingStudio::Lists.addable(list)
RecordingStudio::Lists.find(list.id)
RecordingStudio::Lists.delete(list)
```

`create` accepts `idempotency_key` and `actor`. `add` accepts `actor`. Pass a recording or its id.

## Screens

The index lists names and member counts. New list asks for a name and an optional description. The list page removes a member or deletes the list.

Static interface copy on these screens (and the add-to-list menu) uses Rails I18n keys under `recording_studio.lists`. The gem ships English only in `config/locales/en.yml`. Hosts can override or translate those keys; there is no dependency on `recording_studio_internationalization`.

## Add to a list

`recording_studio_add_to_list` drops a menu on any page that already has a recording. It is not part of the list screens.

```erb
<%= recording_studio_add_to_list(page) %>
```

The menu lists names under the current root. A check sits to the right of a name when the recording is already on that list, so the name stays put. Choosing a name without a check adds it and the check appears. Choosing a checked name removes it and the check goes away. The page stays put. List opens a name field in the menu. Saving creates the list, adds the recording, and checks the new name. The lists page still uses the new-list form when a description is needed.

Pass `text:`, `icon:`, `style:`, `size:`, `show_chevron:`, `placement:`, `parent:`, or `return_to:` when the defaults are wrong. `text: ""` leaves the label off. `icon:` is any heroicon name. `show_chevron: false` hides the arrow. `parent:` defaults to the current root.
