# frozen_string_literal: true

module RecordingStudioEmbeddable
  module RateLimiters
    class Null
      def self.allow?(**)
        true
      end

      def allow?(**)
        true
      end
    end
  end
end
