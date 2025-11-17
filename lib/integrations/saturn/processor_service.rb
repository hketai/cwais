class Integrations::Saturn::ProcessorService < Integrations::BotProcessorService
  pattr_initialize [:event_name!, :hook!, :event_data!]

  private

  def get_response(_session_id, _message_content)
    message = event_data[:message]
    call_saturn(message)
  end

  def process_response(message, response)
    if response == 'conversation_handoff'
      message.conversation.bot_handoff!
    else
      # Parse citations from response if feature_citation is enabled
      parsed_response = parse_citations(response, message)
      create_conversation(message, parsed_response)
    end
  end

  def parse_citations(response, _message)
    assistant = hook.account.saturn_assistants.find_by(id: hook.settings['assistant_id'])
    return { content: response } unless assistant&.feature_citation == true

    # Extract citation patterns like [DOKÜMAN_1], [DOKÜMAN_2], etc.
    citation_pattern = /\[DOKÜMAN_(\d+)\]/i
    citations = response.scan(citation_pattern).flatten.map(&:to_i).uniq

    # Get document names for citations (keep citations in content)
    document_names = {}
    if citations.any?
      documents = assistant.documents.where(id: citations).index_by(&:id)
      citations.each do |doc_id|
        document_names[doc_id] = documents[doc_id]&.name if documents[doc_id]
      end
    end

    result = { content: response }
    result[:additional_attributes] = { citations: document_names } if document_names.any?

    result
  end

  def create_conversation(message, content_params)
    return if content_params.blank?

    conversation = message.conversation
    message_attrs = {
      message_type: :outgoing,
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      sender: assistant_for_message
    }

    # Merge additional_attributes if present
    message_attrs[:additional_attributes] = content_params[:additional_attributes] if content_params[:additional_attributes].present?

    conversation.messages.create!(
      content_params.except(:additional_attributes).merge(message_attrs)
    )
  end

  def assistant_for_message
    hook.account.saturn_assistants.find_by(id: hook.settings['assistant_id'])
  end

  def call_saturn(message)
    assistant = hook.account.saturn_assistants.find_by(id: hook.settings['assistant_id'])
    return 'Saturn assistant not found' unless assistant

    # Check for intent-based handoff before processing
    if assistant.handoff_config.present? && assistant.handoff_config['enabled']
      intent_detector = Saturn::IntentDetectionService.new(
        assistant: assistant,
        message_content: message.content
      )
      detected_intent = intent_detector.detect

      if detected_intent
        handoff_processor = Saturn::HandoffProcessorService.new(
          assistant: assistant,
          conversation: conversation,
          intent: detected_intent
        )
        return 'conversation_handoff' if handoff_processor.perform
      end
    end

    chat_service = Saturn::Llm::AssistantChatService.new(assistant: assistant)
    formatted_history = format_message_history(previous_messages)

    # Build message content with attachments (images, etc.)
    message_builder = Saturn::Llm::OpenAiMessageBuilderService.new(message: message)
    user_message_content = message_builder.generate_content

    chat_service.create_ai_response(
      user_message: user_message_content,
      conversation_history: formatted_history
    )
  rescue StandardError => e
    Rails.logger.error("Saturn integration error: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n")) if Rails.env.development?
    'Üzgünüm, bir hata oluştu. Lütfen tekrar deneyin.'
  end

  def format_message_history(messages)
    messages.map do |msg|
      role_type = msg[:type].downcase == 'user' ? 'user' : 'assistant'
      { role: role_type, content: msg[:content] }
    end
  end

  def previous_messages
    previous_messages = []
    conversation.messages.where(message_type: [:outgoing, :incoming]).where(private: false).offset(1).find_each do |message|
      role = determine_role(message)

      # Build message content with attachments if available
      message_builder = Saturn::Llm::OpenAiMessageBuilderService.new(message: message)
      message_content = message_builder.generate_content

      # Skip if message has no content
      next if message_content.blank? || message_content == 'Message without content'

      previous_messages << { content: message_content, type: role }
    end
    previous_messages
  end

  def determine_role(message)
    message.message_type == 'incoming' ? 'User' : 'Bot'
  end
end
