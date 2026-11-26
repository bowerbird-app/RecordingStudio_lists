# frozen_string_literal: true

module RecordingStudioLists
  module Metrics
    LISTS = :lists
    LIST_ITEMS = :list_items
    LIST_TYPE = Api::TYPE
    ITEM_TYPE = "RecordingStudio::Lists::ListItem"
    API = :operations
    EXPOSE = { api: [API] }.freeze
    AUTHORIZE = lambda do |context|
      return false unless context

      actor = actor_for(context)
      recording = recording_for(context)
      return false if actor.blank? || recording.blank?

      RecordingStudioAccessible.authorized?(
        actor: actor,
        recording: recording,
        role: :view
      )
    end
    LIST_SCOPE = ->(relation) { relation.where(recordable_type: LIST_TYPE) }
    ITEM_SCOPE = ->(relation) { relation.where(recordable_type: ITEM_TYPE) }
    LISTS_TOTAL = "How many lists exist right now. Each row is one list recording."
    LIST_ITEMS_TOTAL = "How many list memberships exist right now. Each row is one list item recording."
    LISTS_OVER_TIME = "Lists created in each period, by created_at."
    LIST_ITEMS_OVER_TIME = "List memberships created in each period, by created_at."

    module_function

    def metrics_available?
      defined?(::RecordingStudioMetrics) && ::RecordingStudioMetrics.respond_to?(:register)
    end

    def register!
      return unless metrics_available?

      register_lists!
      register_list_items!
    end

    def register_lists!
      RecordingStudioMetrics.register(
        LISTS,
        model: RecordingStudio::Recording,
        blast_radius: :site,
        api_authorize: AUTHORIZE,
        scope: LIST_SCOPE
      ) { RecordingStudioLists::Metrics.define_lists(self) }
    end

    def register_list_items!
      RecordingStudioMetrics.register(
        LIST_ITEMS,
        model: RecordingStudio::Recording,
        blast_radius: :site,
        api_authorize: AUTHORIZE,
        scope: ITEM_SCOPE
      ) { RecordingStudioLists::Metrics.define_list_items(self) }
    end

    def define_lists(dsl)
      dsl.count :total, title: "Lists", description: LISTS_TOTAL, expose: EXPOSE
      dsl.timeseries :over_time, title: "Lists over time", description: LISTS_OVER_TIME,
                                 field: :created_at, expose: EXPOSE
    end

    def define_list_items(dsl)
      dsl.count :total, title: "List items", description: LIST_ITEMS_TOTAL, expose: EXPOSE
      dsl.timeseries :over_time, title: "List items over time", description: LIST_ITEMS_OVER_TIME,
                                 field: :created_at, expose: EXPOSE
    end

    def actor_for(context)
      from_method = context.actor if context.respond_to?(:actor)
      return from_method if from_method.present?

      grant = context.access_grant if context.respond_to?(:access_grant)
      grant.actor if grant.respond_to?(:actor)
    end

    def recording_for(context)
      context.access_recording if context.respond_to?(:access_recording)
    end
  end
end
