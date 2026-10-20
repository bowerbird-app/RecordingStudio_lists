# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in recording_studio_lists.gemspec
gemspec

# recording_studio is not published to RubyGems; resolve the gemspec pin from GitHub.
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v4.7.1"
gem "recording_studio_orderable", github: "bowerbird-app/RecordingStudio_orderable", tag: "v0.3.1"
# Required by recording_studio_orderable (not on RubyGems); same tag as the dummy host.
gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.276"

gem "devise"
gem "puma"
gem "sprockets-rails"

group :development, :test do
  gem "debug"
  gem "simplecov", require: false
end

group :development do
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
end
