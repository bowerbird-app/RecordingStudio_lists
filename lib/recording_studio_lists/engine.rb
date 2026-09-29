# frozen_string_literal: true

module RecordingStudioLists
  class Engine < ::Rails::Engine
    isolate_namespace RecordingStudioLists

    class << self
      def apply_model_extensions(target)
        apply_extensions(target, extensions_for(:model, extension_keys_for(target)))
      end

      def apply_controller_extensions(target)
        apply_extensions(target, extensions_for(:controller, extension_keys_for(target)))
      end

      private

      def extensions_for(kind, names)
        hooks = RecordingStudioLists.configuration.hooks
        Array(names).flat_map do |name|
          if kind == :model
            hooks.model_extensions_for(name)
          else
            hooks.controller_extensions_for(name)
          end
        end
      end

      def apply_extensions(target, extensions)
        return unless target

        applied = target.instance_variable_get(:@recording_studio_lists_applied_extensions) || identity_hash

        extensions.flatten.compact.each do |extension|
          next if applied[extension]

          target.class_eval(&extension)
          applied[extension] = true
        end

        target.instance_variable_set(:@recording_studio_lists_applied_extensions, applied)
      end

      def extension_keys_for(target)
        names = [target.name, target.name&.demodulize].compact.uniq
        names.map(&:to_sym)
      end

      def identity_hash
        {}.compare_by_identity
      end
    end

    initializer "recording_studio_lists.before_initialize", before: "recording_studio_lists.load_config" do |_app|
      RecordingStudioLists.configuration.hooks.run(:before_initialize, self)
    end

    initializer "recording_studio_lists.load_config" do |app|
      if app.respond_to?(:config_for)
        begin
          yaml = begin
            app.config_for(:recording_studio_lists)
          rescue StandardError
            nil
          end
          RecordingStudioLists.configuration.merge!(yaml) if yaml.respond_to?(:each)
        rescue StandardError
          nil
        end
      end

      if app.config.respond_to?(:x) && app.config.x.respond_to?(:recording_studio_lists)
        xcfg = app.config.x.recording_studio_lists
        if xcfg.respond_to?(:to_h)
          RecordingStudioLists.configuration.merge!(xcfg.to_h)
        else
          begin
            hash = {}
            xcfg.each_pair { |k, v| hash[k] = v } if xcfg.respond_to?(:each_pair)
            RecordingStudioLists.configuration.merge!(hash) if hash&.any?
          rescue StandardError
            nil
          end
        end
      end

      RecordingStudioLists.configuration.hooks.run(:on_configuration, RecordingStudioLists.configuration)
    end

    initializer "recording_studio_lists.after_initialize", after: "recording_studio_lists.load_config" do |_app|
      RecordingStudioLists.configuration.hooks.run(:after_initialize, self)
    end

    initializer "recording_studio_lists.apply_model_extensions" do
      config.to_prepare do
        next unless defined?(ActiveRecord::Base)

        ActiveRecord::Base.descendants.each do |model|
          next if model.abstract_class?

          RecordingStudioLists::Engine.apply_model_extensions(model)
        end
      end
    end

    initializer "recording_studio_lists.apply_controller_extensions" do
      config.to_prepare do
        next unless defined?(ActionController::Base)

        ActionController::Base.descendants.each do |controller|
          RecordingStudioLists::Engine.apply_controller_extensions(controller)
        end
      end
    end

    initializer "recording_studio_lists.assets" do |app|
      app.config.assets.paths << root.join("app/javascript") if app.config.respond_to?(:assets)
    end

    initializer "recording_studio_lists.importmap", before: "importmap" do |app|
      next unless app.config.respond_to?(:importmap)

      app.config.importmap.paths << root.join("config/importmap.rb")
    end

    initializer "recording_studio_lists.helpers" do
      ActiveSupport.on_load(:action_controller_base) do
        helper RecordingStudioLists::Engine.helpers
      end
    end

    initializer "recording_studio_lists.recordable_types", after: :load_config_initializers do
      next unless defined?(RecordingStudio)

      [
        "RecordingStudio::Lists::List",
        "RecordingStudio::Lists::ListItem"
      ].each do |type_name|
        RecordingStudio.register_recordable_type(type_name)
      end
    end
  end
end
