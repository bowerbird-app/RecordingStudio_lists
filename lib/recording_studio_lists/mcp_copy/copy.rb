# frozen_string_literal: true

module RecordingStudioLists
  module McpCopy
    module Copy
      PURPOSE =
        "A list is a named collection you build from things in this workspace to keep track of them, " \
        "for example Q3 launch coverage. It is a saved workspace collection, not a press kit list section."

      TYPE = <<~TEXT.tr("\n", " ").squeeze(" ").strip.freeze
        #{PURPOSE} Create the list first with create_list, then add or remove records with add_to_list
        and remove_from_list. Use list_list_members for the records on the list. If more than one list
        exists, ask the user which one to use. Do not pick a default.
      TEXT

      LIST = <<~TEXT.tr("\n", " ").squeeze(" ").strip.freeze
        #{PURPOSE} Lists the lists under one parent. Pass parent_id, the id of the record that holds
        the lists. A list cannot be that parent. Use this to pick a list before show_list, update_list,
        delete_list, add_to_list, or list_list_members.
      TEXT

      SHOW = <<~TEXT.tr("\n", " ").squeeze(" ").strip.freeze
        #{PURPOSE} Returns one list when you already have its id. Use list_lists or a create_list
        result to get ids. The list must already exist.
      TEXT

      CREATE = <<~TEXT.tr("\n", " ").squeeze(" ").strip.freeze
        #{PURPOSE} Creates a list. Do this before add_to_list. Pass parent_id, the id of a record
        allowed to hold lists. A list cannot be the parent. name is required. description is optional.
        Send writable fields at the root, not nested under attributes.
      TEXT

      UPDATE = <<~TEXT.tr("\n", " ").squeeze(" ").strip.freeze
        #{PURPOSE} Changes the name and description of a list that already exists. Use this instead
        of create_list. The list must already exist. name is required. If you leave description out,
        the current description is cleared. Send writable fields at the root, not nested under attributes.
      TEXT

      DELETE = <<~TEXT.tr("\n", " ").squeeze(" ").strip.freeze
        #{PURPOSE} Deletes the list and the membership rows on it. This cannot be undone. Records that
        were on the list stay in the workspace. Use remove_from_list when you only want one record off
        the list. The list must already exist.
      TEXT

      ADD = <<~TEXT.tr("\n", " ").squeeze(" ").strip.freeze
        #{PURPOSE} Adds one record to this list. Create the list with create_list first. Pass a record
        id you already have in this workspace. The record has to be in the same workspace. The call is
        rejected when the record is this list, a list item, or in another workspace. Adding a record
        that is already on the list changes nothing and still succeeds.
      TEXT

      REMOVE = <<~TEXT.tr("\n", " ").squeeze(" ").strip.freeze
        #{PURPOSE} Removes one record from this list. The record stays in the workspace. Use this
        instead of delete_list when the list should remain. Take recording_id from list_list_members.
        If that record is not on the list, the call still succeeds. The list must already exist.
      TEXT

      MEMBERS = <<~TEXT.tr("\n", " ").squeeze(" ").strip.freeze
        #{PURPOSE} Returns the records on this list, in list order. Use this to get ids for
        remove_from_list. Each row has id and type. The list must already exist.
      TEXT

      ADDABLE = <<~TEXT.tr("\n", " ").squeeze(" ").strip.freeze
        #{PURPOSE} Returns records in this workspace that you can still add to the list. Use these ids
        with add_to_list. Each row has id and type. Rows leave out this list, other lists, list items,
        and records already on the list. The list must already exist.
      TEXT

      REMOVE_RECORDING_ID = "The id of the record to remove, from list_list_members."

      WRITABLE_INPUTS = {
        "name" => { description: Api::ToolCopy::NAME },
        "description" => { description: Api::ToolCopy::DESCRIPTION }
      }.freeze

      TITLES = {
        "list_lists" => "List lists",
        "show_list" => "Show list",
        "create_list" => "Create list",
        "update_list" => "Update list",
        "delete_list" => "Delete list",
        "add_to_list" => "Add to list",
        "remove_from_list" => "Remove from list",
        "list_list_members" => "List members",
        "list_addable" => "List addable records"
      }.freeze

      DESCRIPTIONS = {
        "list_lists" => LIST,
        "show_list" => SHOW,
        "create_list" => CREATE,
        "update_list" => UPDATE,
        "delete_list" => DELETE,
        "add_to_list" => ADD,
        "remove_from_list" => REMOVE,
        "list_list_members" => MEMBERS,
        "list_addable" => ADDABLE
      }.freeze

      INPUTS = {
        "list_lists" => {},
        "show_list" => {},
        "create_list" => WRITABLE_INPUTS,
        "update_list" => WRITABLE_INPUTS,
        "delete_list" => {},
        "add_to_list" => { "recording_id" => { description: Api::ToolCopy::ADD_RECORDING_ID } },
        "remove_from_list" => { "recording_id" => { description: REMOVE_RECORDING_ID } },
        "list_list_members" => {},
        "list_addable" => {}
      }.freeze

      OUTPUTS = {
        "list_lists" => "The lists under that parent.",
        "show_list" => "The list for that id.",
        "create_list" => "The created list.",
        "update_list" => "The updated list.",
        "delete_list" => "The list as it was, with deleted true.",
        "add_to_list" => "The list after the record is added.",
        "remove_from_list" => "The list after the record is removed.",
        "list_list_members" => "The records on the list.",
        "list_addable" => "The records you can still add to the list."
      }.freeze
    end
  end
end
