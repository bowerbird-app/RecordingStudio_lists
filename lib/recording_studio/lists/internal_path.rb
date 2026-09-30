# frozen_string_literal: true

require "cgi"
require "uri"

module RecordingStudio
  module Lists
    module InternalPath
      module_function

      # Same-origin relative paths only. Absolute and protocol-relative URLs are dropped.
      def sanitize(target)
        candidate = normalized_path(target)
        return if candidate.nil? || unsafe_path?(candidate)

        candidate
      rescue URI::InvalidURIError
        nil
      end

      def normalized_path(target)
        return if target.blank?

        candidate = target.to_s.strip
        return unless candidate.start_with?("/")

        candidate
      end

      def unsafe_path?(candidate)
        return true if unsafe?(candidate)
        return true if unsafe?(CGI.unescape(candidate))

        parsed = URI.parse(candidate)
        parsed.scheme.present? || parsed.host.present? || parsed.opaque.present?
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
