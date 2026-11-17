# frozen_string_literal: true

module RecordingStudioLists
  module Api
    module ToolCopy
      SECTION =
        "A list is a named collection you build from things in this workspace to keep track of them, " \
        "e.g. \"Q3 launch coverage\". Create a list, then add or remove records with Add to list and Remove from list."

      LIST_ROW =
        "id, type, parent_id, root_id, created_at, updated_at, name, and description"

      INDEX = <<~TEXT.tr("\n", " ").squeeze(" ").strip.freeze
        Lists the lists under one parent that you can view. Use this to pick a list before show, update,
        delete, or a membership action. Pass parent_id, the id of the record that holds the lists.
        A list cannot be that parent. You need view access on the parent. Lists you cannot view are left out.
        Each row includes #{LIST_ROW}. Results are paged, 50 per page by default and at most 100, unless
        the host changed the API page limits. Leave pagination_token blank on the first page, then pass
        meta.next_pagination_token to get the next page. Rows are sorted by created_at, oldest first.
        Pass order as desc for newest first. Any other sort is rejected. Pass count as true to get only
        total_count for that parent. An unknown parent, or a parent outside this API scope, is not found.
      TEXT

      SHOW = <<~TEXT.tr("\n", " ").squeeze(" ").strip.freeze
        Returns one list when you already have its id. Use this instead of index.
        You need view access on the list. The record includes #{LIST_ROW}.
        An unknown id, or a list outside this API scope, is not found.
      TEXT

      CREATE = <<~TEXT.tr("\n", " ").squeeze(" ").strip.freeze
        Creates a list. Do this before Add to list. You need edit access on the parent.
        Pass parent_id, the id of a record allowed to hold lists. A list cannot be the parent.
        name is required. Spaces around the name are removed. description is optional, and a blank
        description is stored empty. Pass an Idempotency-Key header to reuse the list already created
        with that key. Returns the new list, including #{LIST_ROW}. A parent that cannot hold a list
        is rejected. A caller without edit access is forbidden.
      TEXT

      UPDATE = <<~TEXT.tr("\n", " ").squeeze(" ").strip.freeze
        Changes the name and description of a list that already exists. Use this instead of create.
        You need edit access on the list. name is required. If you leave description out, the current
        description is cleared. Spaces around the name are removed. The id stays the same.
        Returns the list after the change, with #{LIST_ROW}. A caller without edit access is forbidden.
      TEXT

      DESTROY =
        "Deletes the list and the membership rows on it. This cannot be undone. Records that were on the " \
        "list stay in the workspace. Use Remove from list when you only want one record off the list. You need " \
        "edit access on the list. Returns the list as it was, with deleted true and deleted_via destroyed. " \
        "A caller without edit access is forbidden."

      ADD = <<~TEXT.tr("\n", " ").squeeze(" ").strip.freeze
        Adds one record to this list. The list must already exist. Take recording_id from List addable records,
        or pass a record id you already have in this workspace. You need edit access on the list.
        The record has to be in the same workspace. The call is rejected when the record is this list,
        a list item, or in another workspace. Adding a record that is already on the list changes nothing
        and still succeeds. Returns the list, with #{LIST_ROW}. A caller without edit access is forbidden.
      TEXT

      REMOVE = <<~TEXT.tr("\n", " ").squeeze(" ").strip.freeze
        Removes one record from this list. The record stays in the workspace. Use this instead of delete
        when the list should remain. You need edit access on the list. Take recording_id from List items.
        If that record is not on the list, the call still succeeds. Returns the list, with #{LIST_ROW}.
        A caller without edit access is forbidden.
      TEXT

      ITEMS =
        "Returns the records on this list, in list order. Use this to get ids for Remove from list. You need " \
        "view access on the list. Each row has id and type. The response includes every row. There is no " \
        "page size and no cap. An unknown list, or a list outside this API scope, is not found."

      ADDABLE =
        "Returns records in this workspace that you can still add to the list. Use these ids with Add to list. " \
        "You need view access on the list. The action does not check access on each row. Each row has id and " \
        "type. Rows leave out this list, other lists, list items, and records already on the list. Order is " \
        "created_at, then id. The response includes every matching row. There is no page size and no cap."

      NAME = "The list name. Required. Spaces at the ends are removed. A blank name is rejected."

      DESCRIPTION =
        "Optional note on the list. A blank value is stored empty. On update, leaving this out clears the " \
        "current description."

      PARENT_ID =
        "The id of the record that will hold the list. A list cannot be the parent. The API returns not " \
        "found when that id is outside this scope."

      LIST_ID = "The id of the list, from index or from create."
      ADD_RECORDING_ID = "The id of the record to add, from List addable records or a record id you already have."
      REMOVE_RECORDING_ID = "The id of the record to remove, from List items."
      INDEX_PARENT_ID = "The id of the record that holds the lists. A list cannot be that parent."
      LIMIT = "How many lists to return. The default is 50 and the maximum is 100, unless the host " \
              "changed the API page limits."
      PAGE_TOKEN = "Leave this blank on the first page. Then pass meta.next_pagination_token from the " \
                   "previous response."
      SORT = "Sort field. Only created_at is accepted. Any other sort is rejected."
      ORDER = "Sort direction for created_at. asc is oldest first. desc is newest first."
      COUNT = "Pass true to get only total_count for lists under that parent. limit, sort, order, " \
              "and pagination_token are ignored."
    end

    module IndexQuery
      module_function

      def parameters
        [
          query("parent_id", ToolCopy::INDEX_PARENT_ID, required: true),
          query("limit", ToolCopy::LIMIT, schema: { type: "integer", minimum: 1 }),
          query("pagination_token", ToolCopy::PAGE_TOKEN),
          query("sort", ToolCopy::SORT, schema: { type: "string", enum: ["created_at"], default: "created_at" }),
          query("order", ToolCopy::ORDER, schema: { type: "string", enum: %w[asc desc], default: "asc" }),
          query("count", ToolCopy::COUNT, schema: { type: "boolean", default: false })
        ]
      end

      def query(name, description, schema: { type: "string" }, required: false)
        { name: name, in: "query", required: required, description: description, schema: schema }
      end
    end

    module ToolDescriptions
      module_function

      def type_openapi
        section.merge(writes).merge(reads)
      end

      def add
        action("Add to list", ToolCopy::ADD, ToolCopy::LIST_ID)
      end

      def remove
        action("Remove from list", ToolCopy::REMOVE, ToolCopy::LIST_ID)
      end

      def items
        action("List items", ToolCopy::ITEMS, ToolCopy::LIST_ID)
      end

      def addable
        action("List addable records", ToolCopy::ADDABLE, ToolCopy::LIST_ID)
      end

      def list_id(text)
        {
          name: "id",
          in: "path",
          required: true,
          description: text,
          schema: { type: "string" }
        }
      end

      def section
        {
          tag: { description: ToolCopy::SECTION },
          tags: ["Lists"],
          description: ToolCopy::SECTION,
          details_schema: field_schema
        }
      end
      private_class_method :section

      def reads
        {
          index: { description: ToolCopy::INDEX, parameters: IndexQuery.parameters },
          show: { description: ToolCopy::SHOW, parameters: [list_id(ToolCopy::LIST_ID)] }
        }
      end
      private_class_method :reads

      def writes
        {
          create: { description: ToolCopy::CREATE, request_body: parent_body },
          update: { description: ToolCopy::UPDATE, parameters: [list_id(ToolCopy::LIST_ID)] },
          destroy: { description: ToolCopy::DESTROY, parameters: [list_id(ToolCopy::LIST_ID)] }
        }
      end
      private_class_method :writes

      def field_schema
        {
          type: "object",
          properties: {
            name: { type: "string", description: ToolCopy::NAME },
            description: { type: "string", description: ToolCopy::DESCRIPTION }
          }
        }
      end
      private_class_method :field_schema

      def parent_body
        fields = { parent_id: { description: ToolCopy::PARENT_ID } }
        { content: { "application/json" => { schema: { properties: fields } } } }
      end
      private_class_method :parent_body

      def action(title, description, list_id_text)
        {
          title: title,
          summary: title,
          description: description,
          parameters: [list_id(list_id_text)]
        }
      end
      private_class_method :action
    end
  end
end
