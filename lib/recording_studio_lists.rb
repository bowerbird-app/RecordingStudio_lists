# frozen_string_literal: true

require "recording_studio"
require "recording_studio_lists/version"
require "recording_studio_lists/engine"
require "recording_studio_lists/configuration"
require "recording_studio_lists/capabilities/example"
require "recording_studio/lists"

module RecordingStudioLists
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
    end

    def load_configuration(app)
      merge_yaml_configuration(app)
      merge_x_configuration(app)
      configuration.hooks.run(:on_configuration, configuration)
    end

    def merge_yaml_configuration(app)
      return unless app.respond_to?(:config_for)

      yaml = app.config_for(:recording_studio_lists)
      configuration.merge!(yaml) if yaml.respond_to?(:each)
    rescue StandardError
      nil
    end

    def merge_x_configuration(app)
      return unless app.config.respond_to?(:x) && app.config.x.respond_to?(:recording_studio_lists)

      xcfg = app.config.x.recording_studio_lists
      hash = xcfg.respond_to?(:to_h) ? xcfg.to_h : x_configuration_hash(xcfg)
      configuration.merge!(hash) if hash.respond_to?(:any?) && hash.any?
    rescue StandardError
      nil
    end

    def x_configuration_hash(xcfg)
      return {} unless xcfg.respond_to?(:each_pair)

      hash = {}
      xcfg.each_pair { |key, value| hash[key] = value }
      hash
    end
  end
end
