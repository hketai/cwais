class Saturn::Llm::ConversationFaqService < Saturn::Llm::BaseOpenAiService
  SIMILARITY_THRESHOLD = 0.3

  def initialize(assistant, conversation)
    super()
    @assistant = assistant
    @conversation = conversation
    @conversation_text = conversation.to_llm_text
  end

  # Processes conversation and creates FAQ entries
  # Only processes if there was human-agent interaction
  def generate_and_deduplicate
    return [] unless has_agent_interaction?

    extracted_faqs = extract_faqs_from_conversation
    return [] if extracted_faqs.empty?

    filtered_duplicates, new_unique_faqs = filter_existing_duplicates(extracted_faqs)
    persist_new_faq_entries(new_unique_faqs)
    log_filtered_duplicates(filtered_duplicates) if Rails.env.development?
  end

  private

  attr_reader :conversation_text, :conversation, :assistant

  def has_agent_interaction?
    conversation.first_reply_created_at.present?
  end

  def filter_existing_duplicates(faq_entries)
    duplicates_found = []
    unique_new_entries = []

    faq_entries.each do |entry|
      entry_text = "#{entry['question']}: #{entry['answer']}"
      vector_embedding = Saturn::Llm::EmbeddingService.new.create_vector_embedding(entry_text)
      existing_similar = find_existing_similar_entries(vector_embedding)

      if existing_similar.any?
        duplicates_found << { entry: entry, existing: existing_similar }
      else
        unique_new_entries << entry
      end
    end

    [duplicates_found, unique_new_entries]
  end

  def find_existing_similar_entries(embedding_vector)
    existing_entries = assistant
                       .responses
                       .nearest_neighbors(:embedding, embedding_vector, distance: 'cosine')
    Rails.logger.debug(existing_entries.map { |entry| [entry.question, entry.neighbor_distance] })
    existing_entries.select { |entry| entry.neighbor_distance < SIMILARITY_THRESHOLD }
  end

  def persist_new_faq_entries(faq_entries)
    faq_entries.map do |entry|
      entry_text = "#{entry['question']}: #{entry['answer']}"
      vector_embedding = Saturn::Llm::EmbeddingService.new.create_vector_embedding(entry_text)

      assistant.responses.create!(
        question: entry['question'],
        answer: entry['answer'],
        status: 'pending',
        documentable: conversation,
        embedding: vector_embedding
      )
    end
  end

  def log_filtered_duplicates(filtered_duplicates)
    return if filtered_duplicates.empty?

    Rails.logger.debug('=== Filtered Duplicate FAQs ===')
    filtered_duplicates.each do |filtered|
      Rails.logger.debug { "New entry: #{filtered[:entry]['question']}" }
      Rails.logger.debug('Existing similar entries:')
      filtered[:existing].each do |existing|
        Rails.logger.debug("  - #{existing.question} (distance: #{existing.neighbor_distance})")
      end
    end
  end

  def extract_faqs_from_conversation
    prompt_text = build_faq_extraction_prompt
    api_response = execute_chat_api(messages: [{ role: 'user', content: prompt_text }])
    parse_extracted_faqs(api_response)
  rescue StandardError => e
    Rails.logger.error("Saturn FAQ extraction failed: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n")) if Rails.env.development?
    []
  end

  def build_faq_extraction_prompt
    <<~PROMPT
      Aşağıdaki konuşma içeriğini analiz et ve bu konuşmadan çıkarılabilecek en önemli soru-cevap çiftlerini oluştur.

      Konuşma İçeriği:
      #{@conversation_text}

      Lütfen şu formatta JSON array döndür:
      [
        {
          "question": "Kullanıcının sorduğu soru",
          "answer": "Verilen cevap veya çözüm"
        }
      ]

      Önemli:
      - Sadece gerçekten yararlı ve tekrar kullanılabilir soru-cevap çiftleri oluştur
      - Sorular açık ve anlaşılır olmalı
      - Cevaplar net ve yeterli bilgi içermeli
      - En fazla 5 soru-cevap çifti oluştur
      - Eğer yeterli bilgi yoksa boş array döndür: []
    PROMPT
  end

  def parse_extracted_faqs(response)
    return [] if response.blank?

    # Try to extract JSON from response
    json_match = response.match(/\[.*\]/m)
    return [] unless json_match

    parsed = JSON.parse(json_match[0])
    return [] unless parsed.is_a?(Array)

    parsed.select { |faq| faq.is_a?(Hash) && faq['question'].present? && faq['answer'].present? }
  rescue JSON::ParserError => e
    Rails.logger.error("Saturn FAQ JSON parsing failed: #{e.message}")
    Rails.logger.error("Response: #{response}")
    []
  end
end
