# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"
require_relative "../test_helper"
require_relative "../dummy/config/environment"

require "devise/test/integration_helpers"
require "rails/test_help"

class ListsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(
      email: "lists-#{SecureRandom.hex(4)}@example.com",
      password: "ListsTestPassword!2026",
      password_confirmation: "ListsTestPassword!2026"
    )
    @workspace = Workspace.create!(name: "! Lists #{SecureRandom.hex(4)}")
    @root = RecordingStudio.root_recording_for(@workspace)
    @page = RecordingStudio.record!(
      action: "created",
      recordable: Page.new(title: "Dezeen Board #{SecureRandom.hex(4)}"),
      root_recording: @root,
      parent_recording: @root,
      actor: @user
    ).recording
    sign_in @user
    select_root(@root)
  end

  test "index and new list screens render" do
    get "/lists"

    assert_response :success
    assert_select "h1", text: "Lists", count: 1
    assert_select "h3", text: "No lists yet."
    assert_includes response.body, "Home"
    assert_select "a", text: "List" do
      assert_select "svg[data-flat-pack--icon-name-value='plus']"
    end
    assert_select "a", text: "New list", count: 0

    get "/lists/new"

    assert_response :success
    assert_select "h1", text: "New list", count: 1
    assert_includes response.body, "Lists"
    assert_includes response.body, "Name"
    assert_includes response.body, "Description"
    assert_select "div[class*='md:grid-cols-2']" do
      assert_select "form.flex.flex-col[class*='gap-(--stack-gap-md)']"
    end
    assert_select "input[name='list[name]']"
    assert_select "textarea[name='list[description]']"
    assert_select "button", text: "Create list"
    assert_select "input[name='idempotency_key']"
  end

  test "empty list show renders empty copy and delete control" do
    list = create_list("Bare Shelf")

    get "/lists/#{list.id}"

    assert_response :success
    assert_select "h1", text: "Bare Shelf", count: 1
    assert_includes response.body, "Bare Shelf"
    assert_includes response.body, "0 items"
    assert_includes response.body, "Nothing here yet."
    list_url = "/lists/#{list.id}"
    assert_select "div[class*='md:grid-cols-2']" do
      assert_select "form[action='#{list_url}']", count: 0
    end
    assert_select "[data-controller='flat-pack--trash-button'][data-fp-expand='left']" do
      assert_select "button", text: "Delete list"
      assert_select "form[action='#{list_url}']" do
        assert_select "input[name='_method'][value='delete']"
        assert_select "button", text: "Delete this list?"
      end
    end
    assert_select "form[data-turbo-confirm]", count: 0
    assert_includes response.body, "Lists"
  end

  test "show falls back to Missing when a member recording is gone" do
    list = create_list("Broken")
    original_find = RecordingStudio::Lists.method(:find)
    original_items = RecordingStudio::Lists.method(:items)
    RecordingStudio::Lists.define_singleton_method(:find) { |_id| list }
    RecordingStudio::Lists.define_singleton_method(:items) { |_list| [nil] }

    get "/lists/#{list.id}"

    assert_response :success
    assert_includes response.body, "Missing"
    assert_select "button[aria-label='Remove']", count: 0
  ensure
    RecordingStudio::Lists.define_singleton_method(:find, original_find)
    RecordingStudio::Lists.define_singleton_method(:items, original_items)
  end

  test "create show add remove and delete" do
    post "/lists", params: { list: { name: "  " }, idempotency_key: "blank-#{SecureRandom.hex(4)}" }

    assert_response :unprocessable_entity
    assert_select "p", text: "Name can't be blank."

    key = "create-#{SecureRandom.hex(4)}"
    post "/lists", params: {
      list: { name: "Reading", description: "Magazines" },
      idempotency_key: key
    }

    assert_response :redirect
    show_path = URI.parse(response.headers["Location"]).path
    follow_redirect!

    assert_response :success
    assert_includes response.body, "Reading"
    assert_includes response.body, "Magazines"
    assert_includes response.body, "0 items"
    assert_includes response.body, "List created."

    post "/lists", params: {
      list: { name: "Duplicate", description: "Ignored" },
      idempotency_key: key
    }

    assert_redirected_to show_path
    assert_equal 1, RecordingStudio::Lists::List.where(name: "Reading").count

    get "/lists"
    assert_includes response.body, "Reading"
    assert_select "th", text: "Updated", count: 0
    assert_select "table", count: 0
    assert_select "div[class*='md:grid-cols-2']" do
      assert_select "div[class*='p-[var(--card-padding-md)]']" do
        assert_select "ul.flat-pack-list" do
          assert_select "a", text: "Reading"
        end
      end
    end
    assert_select "nav.flat-pack-page-nav" do
      assert_select "a", text: "Sign out", count: 0
      assert_select "a", text: "Lists", count: 0
      assert_select "[data-controller='recording-studio-root-switchable--root-switch-dropdown']", count: 0
    end
    assert_select "button", text: "Add to list", count: 0

    post "#{show_path}/items", params: { recording_id: @page.id }

    assert_redirected_to show_path
    follow_redirect!

    assert_includes response.body, @page.name
    assert_includes response.body, "1 item"
    assert_includes response.body, "Added."
    assert_select "div[class*='md:grid-cols-2']" do
      assert_select "div[class*='p-[var(--card-padding-md)]']" do
        assert_select "ul.flat-pack-list"
      end
    end
    assert_select "table", count: 0
    assert_select "select[name='recording_id']", count: 0
    assert_select "button", text: "Remove", count: 0
    assert_select "nav.flat-pack-page-nav" do
      assert_select "a", text: "Sign out", count: 0
      assert_select "a", text: "Lists", count: 0
      assert_select "[data-controller='recording-studio-root-switchable--root-switch-dropdown']", count: 0
    end
    assert_select "li", text: /#{Regexp.escape(@page.name)}/ do |items|
      assert_match(/!items-center/, items.first["class"])
      assert_select "button[aria-label='Remove']"
    end

    delete "#{show_path}/items/#{@page.id}"

    assert_redirected_to show_path
    assert RecordingStudio::Recording.exists?(@page.id)
    follow_redirect!
    assert_includes response.body, "Removed."

    list_id = show_path.split("/").last
    delete show_path

    assert_redirected_to "/lists"
    refute RecordingStudio::Recording.exists?(list_id)
    assert RecordingStudio::Recording.exists?(@page.id)
    follow_redirect!
    assert_includes response.body, "List deleted."
  end

  test "add to list menu posts back to the current page" do
    alpha = create_list("Alpha")
    zebra = create_list("Zebra")
    RecordingStudio::Lists.add(alpha, @page, actor: @user)

    queries = sql_during { get "/" }

    assert_response :success
    membership_queries = queries.count { |sql| sql.include?("recording_studio_list_items") }
    assert_equal 1, membership_queries
    assert_select "button", text: "Add to list" do |buttons|
      assert_select buttons.first, "svg[data-flat-pack--icon-name-value='chevron-down']"
      refute_includes buttons.first["class"], "fp-hit-target"
      assert_includes buttons.first["class"], "rounded-[var(--button-border-radius)]"
    end
    assert_select "button.fp-hit-target[aria-label='Add to list']" do |buttons|
      button = buttons.first
      assert_includes button["class"], "rounded-[var(--button-round-border-radius)]"
      assert_includes button["class"], "p-[var(--button-icon-only-padding-md)]"
      assert_includes button["class"], "h-[var(--button-round-size-md)]"
      assert_includes button["class"], "w-[var(--button-round-size-md)]"
      assert_select button, "svg[data-flat-pack--icon-name-value='heart']"
      assert_select button, "svg[data-flat-pack--icon-name-value='chevron-down']", count: 0
      assert_select button, "span", count: 0
    end
    assert_includes response.body, "controllers/recording_studio_lists/add_to_list_controller"
    assert_select "[role=separator]", count: 2
    assert_select "[data-controller='recording-studio-lists--add-to-list']"
    assert_select "button[disabled]", text: "Alpha", count: 0
    assert_select "button[type=submit][form=?]", "add-to-list-1-#{alpha.id}", text: "Alpha" do |buttons|
      assert_includes buttons.first["class"], "[&>svg]:order-last"
      assert_select buttons.first, "svg[data-flat-pack--icon-name-value='check']"
    end
    assert_select "form#add-to-list-1-#{alpha.id}[action=?]", "/lists/#{alpha.id}/items/#{@page.id}" do
      assert_select "input[name=_method][value=delete]"
      assert_select "input[name=recording_id][value=?]", @page.id
      assert_select "input[name=return_to][value=?]", "/"
    end
    assert_select "form#add-to-list-1-#{zebra.id}[method=post][action=?]", "/lists/#{zebra.id}/items" do
      assert_select "input[name=recording_id][value=?]", @page.id
      assert_select "input[name=return_to][value=?]", "/"
      assert_select "input[name=_method]", count: 0
    end
    assert_select "button[type=submit][form=?]", "add-to-list-1-#{zebra.id}", text: "Zebra" do |buttons|
      assert_includes buttons.first["class"], "[&>svg]:order-last"
      assert_select buttons.first, "svg[data-flat-pack--icon-name-value='check']", count: 0
    end
    assert_select "[data-recording-studio-lists--add-to-list-target=reveal]", text: "List"
    new_list = css_select("[data-recording-studio-lists--add-to-list-target=reveal]").first
    query = Rack::Utils.parse_query(URI.parse(new_list["href"]).query)
    assert_equal @page.id.to_s, query["recording_id"]
    assert_equal "/", query["return_to"]
    assert_select "a[href='#{new_list['href']}'] svg[data-flat-pack--icon-name-value='plus']"
    assert_select "form[data-recording-studio-lists--add-to-list-target=create][hidden]", count: 2 do
      assert_select "input[name='list[name]']"
      assert_select "input[name=recording_id][value=?]", @page.id
      assert_select "button", text: "Save"
      assert_select "label", text: "Name"
    end
    assert_includes response.body, 'data-blank-name="Name can&#39;t be blank."'
    assert_match(/data-save-failed="/, response.body)

    get "/lists"
    assert_select "button", text: "Add to list", count: 0
  end

  test "icon only trigger uses copy or custom text and its menu adds" do
    list = create_list("Heart Shelf")

    get "/"

    assert_response :success
    heart = css_select("[data-controller='recording-studio-lists--add-to-list']").find do |node|
      node.at_css("button.fp-hit-target")
    end
    assert heart.at_css("[role=menu]")
    form = heart.at_css("form[action='/lists/#{list.id}/items']")
    view = @controller.view_context

    I18n.backend.store_translations(
      :en,
      recording_studio: {
        lists: {
          add_to_list: {
            trigger: "HOST Add to list",
            icon_only: "Saved for later"
          }
        }
      }
    )
    blank = view.recording_studio_add_to_list(@page, parent: @root, icon: "heart", icon_only: true, text: "")
    named = view.recording_studio_add_to_list(@page, parent: @root, icon: "heart", icon_only: true, text: "Keep this")
    labeled = view.recording_studio_add_to_list(@page, parent: @root)

    assert_includes blank, 'aria-label="Saved for later"'
    refute_includes blank, "HOST Add to list"
    assert_includes named, 'aria-label="Keep this"'
    refute_includes named, "Saved for later"
    assert_includes labeled, "HOST Add to list"
    assert_includes labeled, "chevron-down"
    refute_includes labeled, "fp-hit-target"

    error = assert_raises(ArgumentError) do
      view.recording_studio_add_to_list(@page, parent: @root, icon: "heart", icon_only: true, show_chevron: true)
    end
    assert_match(/chevron/i, error.message)

    post form["action"], params: { recording_id: @page.id, return_to: "/" }

    assert_redirected_to "/"
    assert_includes RecordingStudio::Lists.items(list).map(&:id), @page.id
  ensure
    I18n.reload!
  end

  test "adding from the menu stays on the return path" do
    list = create_list("Reading")

    post "/lists/#{list.id}/items", params: { recording_id: @page.id, return_to: "/docs/methods" }

    assert_redirected_to "/docs/methods"
    follow_redirect!
    assert_includes response.body, "Added."
    assert_includes RecordingStudio::Lists.items(list).map(&:id), @page.id

    other = Workspace.create!(name: "Z Lists #{SecureRandom.hex(4)}")
    other_root = RecordingStudio.root_recording_for(other)
    other_page = RecordingStudio.record!(
      action: "created",
      recordable: Page.new(title: "Elsewhere #{SecureRandom.hex(4)}"),
      root_recording: other_root,
      parent_recording: other_root,
      actor: @user
    ).recording

    post "/lists/#{list.id}/items", params: { recording_id: other_page.id, return_to: "/docs/methods" }

    assert_redirected_to "/docs/methods"
    follow_redirect!
    assert_includes response.body, "That lives somewhere else."

    post "/lists/#{list.id}/items", params: { recording_id: @page.id, return_to: "https://evil.test/phish" }

    assert_redirected_to "/lists/#{list.id}"

    delete "/lists/#{list.id}/items/#{@page.id}", params: { return_to: "/docs/methods" }

    assert_redirected_to "/docs/methods"
    follow_redirect!
    assert_includes response.body, "Removed."
    refute_includes RecordingStudio::Lists.items(list).map(&:id), @page.id

    post "/lists/#{list.id}/items",
         params: { recording_id: @page.id },
         headers: { "X-Lists-Menu" => "1" }

    assert_response :no_content
    assert_includes RecordingStudio::Lists.items(list).map(&:id), @page.id

    delete "/lists/#{list.id}/items/#{@page.id}", headers: { "X-Lists-Menu" => "1" }

    assert_response :no_content
    refute_includes RecordingStudio::Lists.items(list).map(&:id), @page.id
  end

  test "new list can carry a recording home" do
    get "/lists/new", params: { recording_id: @page.id, return_to: "https://evil.test/phish" }

    assert_select "input[name=recording_id][value=?]", @page.id
    assert_select "input[name=return_to]", count: 0

    get "/lists/new", params: { recording_id: @page.id, return_to: "/docs/install" }

    assert_select "input[name=return_to][value=?]", "/docs/install"

    post "/lists", params: {
      list: { name: "  " },
      idempotency_key: "blank-#{SecureRandom.hex(4)}",
      recording_id: @page.id,
      return_to: "/docs/install"
    }

    assert_response :unprocessable_entity
    assert_select "input[name=recording_id][value=?]", @page.id
    assert_select "input[name=return_to][value=?]", "/docs/install"

    post "/lists", params: {
      list: { name: "From the page", description: "Magazines" },
      idempotency_key: "carry-#{SecureRandom.hex(4)}",
      recording_id: @page.id,
      return_to: "/docs/methods"
    }

    assert_redirected_to "/docs/methods"
    follow_redirect!
    assert_includes response.body, "List created."
    list = RecordingStudio::Lists.lists(@root).find { |item| item.name == "From the page" }
    assert_includes RecordingStudio::Lists.items(list).map(&:id), @page.id

    post "/lists", params: {
      list: { name: "Stay here" },
      idempotency_key: "stay-#{SecureRandom.hex(4)}",
      recording_id: @page.id,
      return_to: "//evil.test"
    }

    assert_response :redirect
    assert_match %r{\A/lists/}, URI.parse(response.headers["Location"]).path
  end

  test "creating from the menu adds the recording without leaving" do
    post "/lists",
         params: {
           list: { name: "From the menu" },
           idempotency_key: "menu-#{SecureRandom.hex(4)}",
           recording_id: @page.id
         },
         headers: { "X-Lists-Menu" => "1" }

    assert_response :created
    body = JSON.parse(response.body)
    list = RecordingStudio::Lists.lists(@root).find { |item| item.name == "From the menu" }
    assert_equal list.id, body["id"]
    assert_equal "From the menu", body["name"]
    assert_equal "/lists/#{list.id}/items", body["add_url"]
    assert_equal "/lists/#{list.id}/items/#{@page.id}", body["remove_url"]
    assert_includes RecordingStudio::Lists.items(list).map(&:id), @page.id

    assert_no_difference -> { RecordingStudio::Lists::List.count } do
      post "/lists",
           params: {
             list: { name: "  " },
             idempotency_key: "blank-menu-#{SecureRandom.hex(4)}",
             recording_id: @page.id
           },
           headers: { "X-Lists-Menu" => "1" }
    end

    assert_response :unprocessable_entity
    assert_equal "Name can't be blank.", JSON.parse(response.body)["error"]
  end

  test "layout falls back to the recording studio default" do
    with_layouts(lists: nil, core: nil) do
      get "/lists"

      assert_response :success
      assert_select "body[data-recording-studio-default-layout='true']", count: 1
      assert_select "h1", text: "Lists", count: 1
    end
  end

  test "core layout applies when the lists layout is nil" do
    with_layouts(lists: nil, core: "application") do
      get "/lists"

      assert_response :success
      assert_includes response.body, "min-h-screen"
      assert_select "body[data-recording-studio-default-layout]", count: 0
    end
  end

  test "a lists layout string overrides the core layout" do
    with_layouts(lists: "application", core: "recording_studio/default_layout") do
      get "/lists"

      assert_response :success
      assert_includes response.body, "min-h-screen"
      assert_select "body[data-recording-studio-default-layout]", count: 0
    end
  end

  test "a keyword layout callable overrides the core layout" do
    callable = lambda do |controller:|
      controller.controller_path == "recording_studio_lists/lists" ? "application" : nil
    end

    with_layouts(lists: callable, core: nil) do
      get "/lists"

      assert_response :success
      assert_includes response.body, "min-h-screen"
      assert_select "body[data-recording-studio-default-layout]", count: 0
    end
  end

  test "a false lists layout renders the screen without a layout" do
    with_layouts(lists: false, core: "recording_studio/default_layout") do
      get "/lists"

      assert_response :success
      assert_includes response.body, "No lists yet."
      refute_includes response.body, "<html"
      assert_select "body[data-recording-studio-default-layout]", count: 0
    end
  end

  private

  def with_layouts(lists:, core:)
    previous_lists = RecordingStudioLists.configuration.layout
    previous_core = RecordingStudio.configuration.layout
    RecordingStudioLists.configuration.layout = lists
    RecordingStudio.configuration.layout = core
    yield
  ensure
    RecordingStudioLists.configuration.layout = previous_lists
    RecordingStudio.configuration.layout = previous_core
  end

  def select_root(root)
    patch "/recording_studio_root_switchable/v1/root_switch", params: {
      scope: "all_workspaces",
      root_switch: { root_recording_id: root.id, return_to: "/" }
    }
    follow_redirect!
  end

  def create_list(name)
    RecordingStudio::Lists.create(parent: @root, name: name, actor: @user)
  end

  def sql_during
    queries = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      next if payload[:name] == "SCHEMA" || payload[:cached]

      queries << payload[:sql].to_s
    end
    yield
    queries
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end
end
