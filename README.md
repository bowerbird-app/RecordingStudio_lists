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
