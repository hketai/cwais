# frozen_string_literal: true

# Service to process handoffs based on detected intents
class Saturn::HandoffProcessorService
  pattr_initialize [:assistant!, :conversation!, :intent!]

  def perform
    handoff_target = intent['handoff_target']
    return false unless handoff_target.present?

    case handoff_target['type']
    when 'human'
      handoff_to_human
    when 'assistant'
      handoff_to_assistant(handoff_target['assistant_id'])
    else
      Rails.logger.warn("Unknown handoff target type: #{handoff_target['type']}")
      false
    end
  end

  private

  def handoff_to_human
    # Create a private note with handoff reason
    conversation.messages.create!(
      message_type: :outgoing,
      private: true,
      sender: assistant,
      account: conversation.account,
      inbox: conversation.inbox,
      content: intent['handoff_message'] || "Intent detected: #{intent['name']}"
    )

    # Trigger bot handoff
    conversation.bot_handoff!
    Rails.logger.info("Saturn handoff to human: conversation #{conversation.id}, intent: #{intent['name']}")
    true
  end

  def handoff_to_assistant(target_assistant_id)
    target_assistant = assistant.account.saturn_assistants.find_by(id: target_assistant_id)
    return false unless target_assistant

    # Create a private note about the handoff
    conversation.messages.create!(
      message_type: :outgoing,
      private: true,
      sender: assistant,
      account: conversation.account,
      inbox: conversation.inbox,
      content: intent['handoff_message'].presence || "Handed off to #{target_assistant.name} (Intent: #{intent['name']})"
    )

    # Create or update SaturnInbox for target assistant (this will create the hook automatically)
    conversation.inbox.saturn_inboxes.find_or_create_by!(
      saturn_assistant_id: target_assistant_id
    )

    # Disable the current assistant's hook if it exists
    current_saturn_inbox = conversation.inbox.saturn_inboxes.find_by(saturn_assistant_id: assistant.id)
    if current_saturn_inbox
      current_hook = Integrations::Hook.find_by(
        app_id: 'saturn',
        inbox_id: conversation.inbox.id
      )
      # Check if hook settings match current assistant
      current_hook.update(enabled: false) if current_hook && current_hook.settings['assistant_id'] == assistant.id
    end

    Rails.logger.info("Saturn handoff to assistant: conversation #{conversation.id}, from #{assistant.id} to #{target_assistant_id}, intent: #{intent['name']}")
    true
  end
end
