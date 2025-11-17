# frozen_string_literal: true

# Service to detect intents from message content
# Uses keyword matching for intent detection
class Saturn::IntentDetectionService
  pattr_initialize [:assistant!, :message_content!]

  def detect
    return nil unless assistant.handoff_config.present?
    return nil unless assistant.handoff_config['intents'].present?

    intents = assistant.handoff_config['intents']
    message_lower = message_content.downcase

    # Check each intent's keywords
    intents.each do |intent|
      next unless intent['enabled']
      next unless intent['keywords'].present?

      keywords = intent['keywords'].map(&:downcase)
      matched_keywords = keywords.select { |keyword| message_lower.include?(keyword) }

      if matched_keywords.any?
        Rails.logger.info("Saturn intent detected: #{intent['name']} (matched: #{matched_keywords.join(', ')})")
        return intent
      end
    end

    nil
  end
end
