# frozen_string_literal: true

module RecordingStudioEmbeddable
  module Services
    class BotDetector
      BOT_PATTERN = /bot|crawl|spider|slurp|preview|facebookexternalhit|linkedinbot|twitterbot/i

      def self.bot?(user_agent)
        user_agent.to_s.match?(BOT_PATTERN)
      end
    end
  end
end
