# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"
require "generators/recording_studio_lists/migrations/migrations_generator"

class MigrationsGeneratorTest < Minitest::Test
  def with_destination
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "db/migrate"))
      yield dir, build_generator(dir)
    end
  end

  def build_generator(destination_root, options = {})
    RecordingStudioLists::Generators::MigrationsGenerator.new(
      [],
      options,
      destination_root: destination_root
    )
  end

  def copied_migrations(dir)
    Dir.glob(File.join(dir, "db/migrate/*.rb"))
  end

  def quietly(generator, &block)
    generator.stub(:say, ->(*) {}) do
      generator.stub(:say_status, ->(*) {}, &block)
    end
  end

  def test_copies_each_engine_migration_with_its_own_version
    with_destination do |dir, generator|
      frozen = Time.utc(2026, 11, 14, 12, 0, 0)
      Time.stub(:now, frozen) do
        quietly(generator) { generator.copy_migrations }
      end

      files = copied_migrations(dir)
      names = files.map { |path| File.basename(path).sub(/\A\d+_/, "") }
      versions = files.map { |path| File.basename(path)[/\A\d+/] }

      assert_equal(
        %w[
          create_recording_studio_list_items.rb
          create_recording_studio_lists.rb
          move_list_item_positions_to_orderable.rb
        ].sort,
        names.sort
      )
      assert_equal versions.uniq, versions
      lists_migration = files.find { |path| path.end_with?("create_recording_studio_lists.rb") }
      assert_includes File.read(lists_migration), "create_table :recording_studio_lists"
      assert_includes versions, "20261114120000"
      assert_includes versions, "20261114120002"
    end
  end

  def test_skips_a_migration_that_is_already_in_the_host
    with_destination do |dir, generator|
      quietly(generator) { generator.copy_migrations }
      first_copy = copied_migrations(dir)
      messages = []

      again = build_generator(dir)
      again.stub(:say_status, ->(*) {}) do
        again.stub(:say, ->(*args) { messages << args.first.to_s }) do
          again.copy_migrations
        end
      end

      assert_equal first_copy, copied_migrations(dir)
      assert_includes messages.join("\n"), "create_recording_studio_lists.rb (already exists)"
      assert_includes messages.join("\n"), "Run 'bin/rails db:migrate' to apply the migrations."
    end
  end

  def test_copies_again_when_existing_migrations_are_not_skipped
    with_destination do |dir, generator|
      Time.stub(:now, Time.utc(2026, 11, 14, 12, 0, 0)) do
        quietly(generator) { generator.copy_migrations }
      end
      later = build_generator(dir, skip_existing: false)
      Time.stub(:now, Time.utc(2026, 11, 14, 12, 0, 10)) do
        quietly(later) { later.copy_migrations }
      end

      assert_equal 6, copied_migrations(dir).size
    end
  end

  def test_reports_when_the_engine_has_no_migration_directory
    with_destination do |dir, generator|
      messages = []
      Dir.mktmpdir do |source|
        generator.class.stub(:source_root, source) do
          generator.stub(:say, ->(*args) { messages << args.first.to_s }) do
            generator.copy_migrations
          end
        end
      end

      assert_empty copied_migrations(dir)
      assert_includes messages, "No migrations found in RecordingStudioLists engine."
    end
  end

  def test_reports_when_the_migration_directory_is_empty
    with_destination do |dir, generator|
      messages = []
      Dir.mktmpdir do |source|
        FileUtils.mkdir_p(File.join(source, "db/migrate"))
        generator.class.stub(:source_root, source) do
          generator.stub(:say, ->(*args) { messages << args.first.to_s }) do
            generator.copy_migrations
          end
        end
      end

      assert_empty copied_migrations(dir)
      assert_includes messages, "No migrations found in RecordingStudioLists engine."
    end
  end
end
