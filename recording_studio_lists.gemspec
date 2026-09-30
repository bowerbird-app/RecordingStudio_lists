# frozen_string_literal: true

require_relative "lib/recording_studio_lists/version"

Gem::Specification.new do |spec|
  spec.name        = "recording_studio_lists"
  spec.version     = RecordingStudioLists::VERSION
  spec.authors     = ["Bowerbird"]
  spec.homepage    = "https://github.com/bowerbird-app/RecordingStudio_lists"
  spec.summary     = "Named lists of recordings for Recording Studio"
  spec.description = "List and list item recordables, a Ruby API, and screens " \
                     "for creating lists and adding or removing members."
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/bowerbird-app/RecordingStudio_lists"
  spec.metadata["changelog_uri"] = "https://github.com/bowerbird-app/RecordingStudio_lists/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"].reject do |path|
      path == ".cursor" || path.start_with?(".cursor/")
    end
  end

  spec.add_dependency "rails", "~> 8.1.0"
  spec.add_dependency "recording_studio", "~> 4.2"
end
