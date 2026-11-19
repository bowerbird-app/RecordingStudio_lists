# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in recording_studio_lists.gemspec
gemspec

# recording_studio is not published to RubyGems; resolve the gemspec pin from GitHub.
gem "recording_studio", "~> 7.8", github: "bowerbird-app/RecordingStudio", tag: "v7.8.0"
gem "recording_studio_orderable", "~> 0.12", github: "bowerbird-app/RecordingStudio_orderable", tag: "v0.12.0"
# Required by the gemspec Accessible pin (not on RubyGems).
gem "recording_studio_accessible", "~> 0.58", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.58.0"
# Required by accessible (query API only; not on RubyGems).
gem "recording_studio_trashable", "~> 1.3", github: "bowerbird-app/RecordingStudio_trashable", tag: "v1.3.0",
                                            require: false
# Required by trashable (not on RubyGems); same tag as the dummy host.
gem "recording_studio_metrics", "~> 0.10", github: "bowerbird-app/RecordingStudio_metrics", tag: "v0.10.0"
# Required by recording_studio_orderable (not on RubyGems).
gem "flat_pack", "~> 0.2", github: "bowerbird-app/flatpack", tag: "v0.2.0"
gem "minitest", ">= 5.26", "< 6"
gem "view_component", "~> 4.19"

gem "devise"
gem "puma"
gem "sprockets-rails"

group :development, :test do
  gem "debug"
  gem "recording_studio_admin", "~> 2.19", github: "bowerbird-app/RecordingStudio_admin", tag: "v2.19.1"
  gem "recording_studio_api", "~> 1.20", github: "bowerbird-app/RecordingStudio_api", tag: "v1.20.0"
  gem "recording_studio_icons", "~> 0.5", github: "bowerbird-app/RecordingStudio_icons", tag: "v0.5.0"
  gem "recording_studio_logs", "~> 0.9", github: "bowerbird-app/RecordingStudio_logs", tag: "v0.9.0"
  gem "recording_studio_moveable", "~> 6.1", github: "bowerbird-app/RecordingStudio_moveable", tag: "v6.1.0"
  gem "redis", "~> 5.3"
  gem "simplecov", require: false
end

group :development do
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
end
