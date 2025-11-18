class Saturn::Llm::ContactNotesService < Saturn::Llm::BaseOpenAiService
  def initialize(assistant, conversation)
    super()
    @assistant = assistant
    @conversation = conversation
    @contact = conversation.contact
    @conversation_content = conversation.to_llm_text
  end

  # Creates and merges contact notes from conversation
  def generate_and_update_notes
    return unless has_agent_interaction?

    summarized_notes = create_notes_summary
    return if summarized_notes.blank?

    merge_notes_to_contact(summarized_notes)
  end

  private

  attr_reader :conversation_content, :conversation, :assistant, :contact

  def has_agent_interaction?
    conversation.first_reply_created_at.present?
  end

  def create_notes_summary
    prompt_text = build_contact_summary_prompt
    execute_chat_api(messages: [{ role: 'user', content: prompt_text }])
  rescue StandardError => e
    Rails.logger.error("Saturn contact notes summary creation failed: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n")) if Rails.env.development?
    nil
  end

  def build_contact_summary_prompt
    previous_notes = contact.notes.latest.limit(5).pluck(:content).join("\n\n")

    prompt_base = <<~PROMPT
      Bu konuşmayı analiz ederek contact için önemli bilgileri, tercihleri ve geçmiş durumları özetle.

      Konuşma:
      #{@conversation_content}
    PROMPT

    if previous_notes.present?
      prompt_base += <<~PROMPT

        Önceki Notlar:
        #{previous_notes}

        Yeni bilgileri mevcut notlarla birleştir, tekrarları kaldır ve güncelle.
      PROMPT
    end

    prompt_base += <<~PROMPT

      Kurallar:
      - Özet ve kısa notlar oluştur
      - Yalnızca önemli bilgileri dahil et
      - Contact tercihleri, sorunları ve geçmiş etkileşimlerini özetle
      - Bu notlar ileride referans için kullanılacak
    PROMPT

    prompt_base
  end

  def merge_notes_to_contact(summary_text)
    # Update recent note if exists, otherwise create new
    recent_entry = contact.notes.where('created_at > ?', 1.hour.ago).latest.first

    if recent_entry
      recent_entry.update!(content: summary_text)
    else
      contact.notes.create!(
        content: summary_text,
        account_id: contact.account_id
      )
    end
  rescue StandardError => e
    Rails.logger.error("Saturn contact notes merge failed: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n")) if Rails.env.development?
  end
end
