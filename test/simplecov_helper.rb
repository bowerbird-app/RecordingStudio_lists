# frozen_string_literal: true

return if ENV["DISABLE_SIMPLECOV"] == "true"

begin
  require "simplecov"
rescue LoadError
  return
end

return if SimpleCov.running

module RecordingStudioListsCoverage
  ROOT = File.expand_path("..", __dir__)

  def self.app_or_lib?(filename)
    relative = filename.to_s.delete_prefix("#{ROOT}/")
    relative.start_with?("app/", "lib/")
  end
end

# Per-process reports are partial. `rake test:coverage` prints the merged app/lib result.
SimpleCov.formatters = []

SimpleCov.start do
  enable_coverage :branch
  root RecordingStudioListsCoverage::ROOT
  coverage_dir File.join(RecordingStudioListsCoverage::ROOT, "coverage")
  command_name "recording-studio-lists-#{Process.pid}"
  track_files "{app,lib}/**/*.rb"
  add_filter do |source|
    !RecordingStudioListsCoverage.app_or_lib?(source.filename)
  end
end
