# frozen_string_literal: true

require "cgi"
require "uri"

module RecordingStudio
  module Lists
    module InternalPath
      module_function

      # Same-origin relative paths only. Absolute and protocol-relative URLs are dropped.
      def sanitize(target)
        return if target.blank?

        candidate = target.to_s.strip
        return unless candidate.start_with?("/")
        return if unsafe?(candidate)

        decoded = CGI.unescape(candidate)
        return if unsafe?(decoded)

        parsed = URI.parse(candidate)
        return if parsed.scheme.present? || parsed.host.present? || parsed.opaque.present?

        candidate
      rescue URI::InvalidURIError
        nil
      end

      def unsafe?(value)
        value.match?(/[[:cntrl:]]/) ||
          value.start_with?("//") ||
          value.include?("\\") ||
          value.match?(%r{\A/\\}) ||
          value.match?(%r{\A/%2f}i)
      end
      private_class_method :unsafe?
    end
  end
end
