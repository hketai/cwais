class SaturnListener < BaseListener
  include ::Events::Types

  def conversation_resolved(event)
    conversation = extract_conversation_and_account(event)[0]
    inbox = conversation.inbox
    saturn_connection = inbox.saturn_inboxes.first
    return unless saturn_connection

    saturn_assistant = saturn_connection.saturn_assistant
    return unless saturn_assistant

    # Process contact memory if enabled
    Saturn::Llm::ContactNotesService.new(saturn_assistant, conversation).generate_and_update_notes if saturn_assistant.feature_memory == true

    # Process conversation FAQs if enabled
    return unless saturn_assistant.feature_faq == true

    Saturn::Llm::ConversationFaqService.new(saturn_assistant, conversation).generate_and_deduplicate
  end
end
