# frozen_string_literal: true

require "test_helper"

class ListRecordableLabelsTest < ActiveSupport::TestCase
  test "list recordable labels keep english constants and resolve at call time" do
    assert_equal "List", RecordingStudio::Lists::List::LABEL
    assert_equal "List item", RecordingStudio::Lists::ListItem::LABEL
    assert_equal "List items", RecordingStudio::Lists::ListItem::PLURAL_LABEL

    declaration = RecordingStudio.recordable_declaration_for("RecordingStudio::Lists::List")
    item_declaration = RecordingStudio.recordable_declaration_for("RecordingStudio::Lists::ListItem")
    assert_equal "List", declaration.label
    assert_equal "List item", item_declaration.label
    assert_equal "List items", item_declaration.plural_label

    I18n.with_locale(:en) do
      assert_equal "List", RecordingStudio::Lists::List.recordable_type_label
      assert_equal "List item", RecordingStudio::Lists::ListItem.recordable_type_label
      assert_equal "List items", RecordingStudio::Lists::ListItem.recordable_type_plural_label
    end
  end

  test "list recordable labels follow a non-english locale while constants stay english" do
    I18n.available_locales = Array(I18n.available_locales) | %i[en fr]
    I18n.backend.store_translations(
      :fr,
      recording_studio: {
        lists: {
          recordables: {
            list: { label: { one: "Liste", other: "Listes" } },
            list_item: { label: { one: "Élément de liste", other: "Éléments de liste" } }
          }
        }
      }
    )

    I18n.with_locale(:fr) do
      assert_equal "List", RecordingStudio::Lists::List::LABEL
      assert_equal "List item", RecordingStudio::Lists::ListItem::LABEL
      assert_equal "List items", RecordingStudio::Lists::ListItem::PLURAL_LABEL
      assert_equal "Liste", RecordingStudio::Lists::List.recordable_type_label
      assert_equal "Élément de liste", RecordingStudio::Lists::ListItem.recordable_type_label
      assert_equal "Éléments de liste", RecordingStudio::Lists::ListItem.recordable_type_plural_label
    end
  end
end
