# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in recording_studio_lists.gemspec
gemspec

# recording_studio is not published to RubyGems; resolve the gemspec pin from GitHub.
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v6.3.0"
gem "recording_studio_orderable", github: "bowerbird-app/RecordingStudio_orderable", tag: "v0.4.8"
# Required by the gemspec Accessible pin (not on RubyGems). Latest tag is v0.24.0.
gem "recording_studio_accessible", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.24.0"
# Required by accessible (query API only; not on RubyGems); same tag as the dummy host.
gem "recording_studio_trashable", github: "bowerbird-app/RecordingStudio_trashable", tag: "v0.12.2", require: false
# Required by trashable (not on RubyGems); same tag as the dummy host.
gem "recording_studio_metrics", github: "bowerbird-app/RecordingStudio_metrics", tag: "v0.7.2"
# Required by recording_studio_orderable (not on RubyGems); same tag as the dummy host.
gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.341"
gem "minitest", ">= 5.26", "< 6"
gem "view_component", "4.19.0"

gem "devise"
gem "puma"
gem "sprockets-rails"

group :development, :test do
  gem "debug"
  gem "recording_studio_admin", github: "bowerbird-app/RecordingStudio_admin", tag: "v2.11.0"
  gem "recording_studio_api", github: "bowerbird-app/RecordingStudio_api", tag: "v0.21.3"
  gem "recording_studio_icons", github: "bowerbird-app/RecordingStudio_icons", tag: "v0.2.0"
  gem "recording_studio_logs", github: "bowerbird-app/RecordingStudio_logs", tag: "v0.7.3"
  gem "recording_studio_moveable", github: "bowerbird-app/RecordingStudio_moveable", tag: "v4.1.0"
  gem "redis", "~> 5.3"
  gem "simplecov", require: false
end

group :development do
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
end
