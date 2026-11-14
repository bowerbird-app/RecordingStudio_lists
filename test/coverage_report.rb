# frozen_string_literal: true

require "simplecov"

ROOT = File.expand_path("..", __dir__)
RESULTSET = File.join(ROOT, "coverage/.resultset.json")
MINIMUM_LINE_COVERAGE = 94.0

abort "No coverage resultset at #{RESULTSET}. Run bundle exec rake test:all." unless File.exist?(RESULTSET)

module CoverageSummary
  class Formatter
    def format(result)
      line = result.coverage_statistics[:line]
      branch = result.coverage_statistics[:branch]
      puts "app/lib line coverage: #{line.percent.round(2)}% (#{line.covered}/#{line.total})"
      puts "app/lib branch coverage: #{branch.percent.round(2)}% (#{branch.covered}/#{branch.total})"

      missed = result.files.select { |file| file.coverage_statistics[:line]&.missed.to_i.positive? }
      missed.sort_by { |file| -file.coverage_statistics[:line].missed }.each do |file|
        stats = file.coverage_statistics[:line]
        relative = file.filename.delete_prefix("#{ROOT}/")
        puts "  #{relative} missed #{stats.missed}/#{stats.total}"
      end
    end
  end
end

SimpleCov.collate([RESULTSET]) do
  root ROOT
  coverage_dir File.join(ROOT, "coverage")
  enable_coverage :branch
  minimum_coverage line: MINIMUM_LINE_COVERAGE
  formatter SimpleCov::Formatter::MultiFormatter.new(
    [
      SimpleCov::Formatter::HTMLFormatter,
      CoverageSummary::Formatter
    ]
  )
  add_filter do |source|
    relative = source.filename.to_s.delete_prefix("#{ROOT}/")
    !(relative.start_with?("app/") || relative.start_with?("lib/"))
  end
end
