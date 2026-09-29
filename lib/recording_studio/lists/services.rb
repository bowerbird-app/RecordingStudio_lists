# frozen_string_literal: true

require "digest"

module RecordingStudio
  module Lists
    module Services
      LIST_TYPE = "RecordingStudio::Lists::List"
      ITEM_TYPE = "RecordingStudio::Lists::ListItem"

      module Resolve
        RESULT = RecordingStudio::Services::BaseService::Result

        def recording_for(recording_or_id)
          return recording_or_id if recording_or_id.is_a?(RecordingStudio::Recording)
          return if recording_or_id.blank?

          RecordingStudio::Recording.find_by(id: recording_or_id)
        end

        def require_list(recording_or_id)
          recording = recording_for(recording_or_id)
          return recording if recording&.recordable_type == LIST_TYPE

          halt(InvalidList.new)
        end

        def require_target(recording_or_id)
          recording = recording_for(recording_or_id)
          return recording if recording&.persisted?

          halt(MissingTarget.new)
        end

        def halt(error)
          RESULT.new(success: false, error: error)
        end

        def list_item_recordings(list)
          RecordingStudio::Recording
            .where(parent_recording_id: list.id, recordable_type: ITEM_TYPE)
            .includes(recordable: :item_recording)
            .to_a
            .sort_by { |child| [child.recordable.position.to_i, child.id.to_s] }
        end

        def lock_list!(list)
          # lock is lazy until the relation loads.
          RecordingStudio::Recording.lock_ids!([list.id]).load
        end
      end

      class Create < RecordingStudio::Services::BaseService
        include Resolve

        def initialize(parent:, name:, description: nil, idempotency_key: nil, actor: nil)
          @parent = parent
          @name = name
          @description = description
          @idempotency_key = idempotency_key
          @actor = actor
        end

        def perform
          return halt(BlankName.new) if @name.to_s.strip.empty?

          parent = recording_for(@parent)
          unless parent&.persisted? && RecordingStudio.parent_allowed?(child_type: LIST_TYPE, parent_recording: parent)
            return halt(ParentNotAllowed.new)
          end

          key = @idempotency_key.presence
          recording = if key
                        # record! reuses an idempotency key only after a recording already exists.
                        with_idempotency_lock(key) { existing_list(key) || record_list(parent, key) }
                      else
                        record_list(parent, nil)
                      end
          success(recording)
        end

        private

        def record_list(parent, key)
          list = RecordingStudio::Lists::List.new(name: @name.to_s.strip, description: @description.presence)
          RecordingStudio.record!(
            action: "created",
            recordable: list,
            root_recording: parent.root_recording_or_self,
            parent_recording: parent,
            actor: @actor,
            idempotency_key: key
          ).recording
        end

        def existing_list(key)
          RecordingStudio::Event
            .joins(:recording)
            .where(action: "created", idempotency_key: key)
            .where(recording_studio_recordings: { recordable_type: LIST_TYPE })
            .order(:created_at, :id)
            .first
            &.recording
        end

        def with_idempotency_lock(key)
          lock_id = Digest::SHA256.digest(key.to_s).unpack1("q>")
          RecordingStudio::Recording.transaction do
            RecordingStudio::Recording.connection.execute("SELECT pg_advisory_xact_lock(#{lock_id.to_i})")
            yield
          end
        end
      end

      class Add < RecordingStudio::Services::BaseService
        include Resolve

        def initialize(list:, target:, actor: nil)
          @list = list
          @target = target
          @actor = actor
        end

        def perform
          list = require_list(@list)
          return list if list.is_a?(RESULT)

          target = require_target(@target)
          return target if target.is_a?(RESULT)

          return halt(SelfTarget.new) if target.id == list.id
          return halt(ListItemTarget.new) if target.recordable_type == ITEM_TYPE
          return halt(DifferentRoot.new) if target.root_recording_id != list.root_recording_id

          RecordingStudio::Recording.transaction do
            lock_list!(list)
            already_there = list_item_recordings(list).any? do |child|
              child.recordable.item_recording_id.to_s == target.id.to_s
            end
            unless already_there
              position = next_position(list)
              list.record(RecordingStudio::Lists::ListItem, parent_recording: list, actor: @actor) do |item|
                item.item_recording = target
                item.position = position
              end
            end
          end

          success(target)
        end

        private

        def next_position(list)
          positions = list_item_recordings(list).map { |child| child.recordable.position.to_i }
          return 1 if positions.empty?

          positions.max + 1
        end
      end

      class Remove < RecordingStudio::Services::BaseService
        include Resolve

        def initialize(list:, target:)
          @list = list
          @target = target
        end

        def perform
          list = require_list(@list)
          return list if list.is_a?(RESULT)

          target = require_target(@target)
          return target if target.is_a?(RESULT)

          RecordingStudio::Recording.transaction do
            lock_list!(list)
            child = list_item_recordings(list).find do |item|
              item.recordable.item_recording_id.to_s == target.id.to_s
            end
            child&.destroy!
          end

          success(target)
        end
      end

      class Items < RecordingStudio::Services::BaseService
        include Resolve

        def initialize(list:)
          @list = list
        end

        def perform
          list = require_list(@list)
          return list if list.is_a?(RESULT)

          targets = list_item_recordings(list).map { |child| child.recordable.item_recording }
          success(targets)
        end
      end

      class Lists < RecordingStudio::Services::BaseService
        include Resolve

        def initialize(parent:)
          @parent = parent
        end

        def perform
          parent = recording_for(@parent)
          return halt(ParentNotAllowed.new) unless parent&.persisted?

          recordings = parent.child_recordings.where(recordable_type: LIST_TYPE).includes(:recordable).to_a
          ordered = recordings.sort_by { |recording| [recording.recordable.name.to_s, recording.id.to_s] }
          success(ordered)
        end
      end

      class Find < RecordingStudio::Services::BaseService
        include Resolve

        def initialize(id:)
          @id = id
        end

        def perform
          list = require_list(@id)
          return list if list.is_a?(RESULT)

          success(list)
        end
      end

      class Addable < RecordingStudio::Services::BaseService
        include Resolve

        def initialize(list:)
          @list = list
        end

        def perform
          list = require_list(@list)
          return list if list.is_a?(RESULT)

          taken_ids = list_item_recordings(list).map { |child| child.recordable.item_recording_id }
          scope = RecordingStudio::Recording.where(root_recording_id: list.root_recording_id)
          scope = scope.where.not(id: list.id)
          scope = scope.where.not(recordable_type: [LIST_TYPE, ITEM_TYPE])
          scope = scope.where.not(id: taken_ids) if taken_ids.any?
          success(scope.order(:created_at, :id).to_a)
        end
      end

      class Delete < RecordingStudio::Services::BaseService
        include Resolve

        def initialize(list:)
          @list = list
        end

        def perform
          recording = recording_for(@list)
          return success(nil) if recording.nil?
          return halt(InvalidList.new) unless recording.recordable_type == LIST_TYPE

          RecordingStudio::Recording.transaction do
            lock_list!(recording)
            children = RecordingStudio::Recording.where(parent_recording_id: recording.id).to_a
            owned, _others = children.partition { |child| child.recordable_type == ITEM_TYPE }
            owned.each(&:destroy!)
            recording.destroy!
          end

          success(recording)
        end
      end
    end
  end
end
