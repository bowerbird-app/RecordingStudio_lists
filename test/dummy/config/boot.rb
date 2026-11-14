ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.

# `bin/rails test` boots the app before test_helper. Start coverage first so lib/ is measured.
require_relative "../../simplecov_helper" if ARGV.include?("test")
# require "bootsnap/setup" # Speed up boot time by caching expensive operations.
