# Incoming Message Service for WhatsApp Web
# Processes messages received from WhatsApp Web client
require 'stringio'
require 'base64'

class WhatsappWeb::IncomingMessageService
  pattr_initialize [:channel!, :message_data!]

  def perform
    Rails.logger.info '[WHATSAPP_WEB] ===== INCOMING MESSAGE SERVICE START ====='
    Rails.logger.info "[WHATSAPP_WEB] Channel ID: #{channel.id}"
    Rails.logger.info "[WHATSAPP_WEB] Message ID: #{message_data[:id]}"
    Rails.logger.info "[WHATSAPP_WEB] From: #{message_data[:from]}"
    Rails.logger.info "[WHATSAPP_WEB] To: #{message_data[:to]}"
    Rails.logger.info "[WHATSAPP_WEB] FromMe: #{message_data[:fromMe]} (#{message_data[:fromMe].class})"
    Rails.logger.info "[WHATSAPP_WEB] Type: #{message_data[:type]}"
    Rails.logger.info "[WHATSAPP_WEB] Body: #{message_data[:body]&.first(50)}"
    Rails.logger.info "[WHATSAPP_WEB] Full message_data keys: #{message_data.keys.inspect}"

    return unless message_data.present?

    # Filter out unwanted messages (additional check in case Node.js filter missed something)
    if should_ignore_message?
      Rails.logger.info '[WHATSAPP_WEB] ⚠️ Message ignored by should_ignore_message? check'
      return
    end

    # Check if inbox exists, if not, log error and return
    unless channel.inbox.present?
      Rails.logger.error "[WHATSAPP_WEB] ❌ Inbox not found for channel #{channel.id}. Message cannot be processed."
      return
    end

    set_contact
    unless @contact
      Rails.logger.error '[WHATSAPP_WEB] ❌ Contact could not be set'
      return
    end

    Rails.logger.info "[WHATSAPP_WEB] Contact set: ID=#{@contact.id}, name=#{@contact.name}"

    ActiveRecord::Base.transaction do
      set_conversation
      Rails.logger.info "[WHATSAPP_WEB] Conversation set: ID=#{@conversation.id}"

      # Check if body contains vCard data and parse it BEFORE creating message
      if message_data[:vcards].blank? && message_data[:body].to_s.include?('BEGIN:VCARD')
        Rails.logger.info "[WHATSAPP_WEB] 📇 vCard detected in body, parsing..."
        parse_vcard_from_body
      end

      create_message
      Rails.logger.info "[WHATSAPP_WEB] Message created: ID=#{@message.id}" if @message

      attach_contacts if message_data[:vcards].present?
      attach_files if message_data[:attachments].present?
    end

    Rails.logger.info '[WHATSAPP_WEB] ===== INCOMING MESSAGE SERVICE SUCCESS ====='
  rescue StandardError => e
    Rails.logger.error "[WHATSAPP_WEB] ❌ ERROR processing message: #{e.class.name}: #{e.message}"
    Rails.logger.error "[WHATSAPP_WEB] Backtrace: #{e.backtrace.first(10).join("\n")}" if Rails.env.development?
    raise
  end

  private

  def should_ignore_message?
    from = message_data[:from].to_s
    from_me = message_data[:fromMe] == true || message_data[:fromMe] == 'true'
    to = message_data[:to].to_s

    Rails.logger.info "[WHATSAPP_WEB] should_ignore_message? check: from=#{from}, to=#{to}, fromMe=#{from_me}, type=#{message_data[:type]}, body=#{message_data[:body]&.first(30)}"

    # Mobilden gönderilen mesajlar (fromMe=true) için özel kontrol
    # Bu mesajlar panele gelmeli, sadece panel'den gönderilen mesajlar duplicate olarak filtrelenmeli
    if from_me
      Rails.logger.info '[WHATSAPP_WEB] fromMe=true detected, allowing message through (will be checked for duplicates in create_message)'
      return false # Mobilden gönderilen mesajları geçir
    end

    # 1. Group messages have @g.us suffix
    return true if from.include?('@g.us')

    # 2. Status messages
    return true if from == 'status@broadcast' || message_data[:is_status] == true

    # 3. System/notification messages
    return true if message_data[:is_notification] == true || message_data[:type] == 'notification'

    # 4. Protocol/system messages
    return true if %w[protocol system].include?(message_data[:type].to_s)

    # 5. Empty messages without media (likely system messages)
    # BUT: Allow media messages even if body is empty
    return true if message_data[:body].blank? && message_data[:attachments].blank? && !from.include?('@g.us')

    # 6. Messages from broadcast lists
    return true if from == 'status@broadcast'

    false
  end

  def set_contact
    Rails.logger.info "[WHATSAPP_WEB] Setting contact: from=#{message_data[:from]}, to=#{message_data[:to]}, fromMe=#{message_data[:fromMe]}"

    phone_number = normalized_counterpart_number
    Rails.logger.info "[WHATSAPP_WEB] Normalized counterpart phone number: #{phone_number}"

    if phone_number.blank?
      Rails.logger.error '[WHATSAPP_WEB] ❌ Counterpart phone number is blank after normalization'
      return
    end

    contact_inbox = ::ContactInboxWithContactBuilder.new(
      source_id: phone_number,
      inbox: channel.inbox,
      contact_attributes: {
        name: message_data[:contact_name] || phone_number,
        phone_number: phone_number
      }
    ).perform

    @contact_inbox = contact_inbox
    @contact = contact_inbox.contact

    Rails.logger.info "[WHATSAPP_WEB] Contact set: ID=#{@contact.id}, name=#{@contact.name}, phone=#{@contact.phone_number}"
  end

  def set_conversation
    @conversation = if channel.inbox.lock_to_single_conversation
                      @contact_inbox.conversations.last
                    else
                      @contact_inbox.conversations.where.not(status: :resolved).last
                    end

    return if @conversation

    @conversation = ::Conversation.create!(conversation_params)
  end

  def create_message
    message_source_id = message_data[:id].to_s
    from_me = message_originates_from_channel?

    Rails.logger.info "[WHATSAPP_WEB] Creating message: source_id=#{message_source_id}, fromMe=#{from_me}, from=#{message_data[:from]}, to=#{message_data[:to]}"

    # KATMAN 1: ExternalID kontrolü (en hızlı - WhatsApp message ID ile kontrol)
    # Panel'den gönderilen mesajların source_id'si WhatsApp message ID olarak kaydedilir
    existing_message = @conversation.messages.find_by(source_id: message_source_id)
    if existing_message
      Rails.logger.info "[WHATSAPP_WEB] ⚠️ KATMAN 1: Message #{message_source_id} already exists (externalId match), skipping duplicate"
      @message = existing_message
      return
    end

    # KATMAN 2: Panel'den gönderilen mesaj kontrolü (outgoing messages)
    # Panel'den gönderilen mesajlar outgoing olarak kaydedilir ve source_id'leri WhatsApp message ID'dir
    panel_message = channel.inbox.messages.outgoing.find_by(source_id: message_source_id)
    if panel_message
      Rails.logger.info "[WHATSAPP_WEB] ⚠️ KATMAN 2: Message #{message_source_id} is a panel-sent message (outgoing with same source_id), skipping"
      @message = panel_message
      return
    end

    # KATMAN 3: fromMe=true mesajlar için race condition koruması
    # Bazen panel'den mesaj gönderilir ama source_id henüz kaydedilmemiş olabilir
    # Bu durumda sadece source_id kontrolü yapıyoruz (içerik kontrolü yapmıyoruz çünkü telefondan gönderilen mesajlar farklı içerikli olabilir)
    if from_me
      Rails.logger.info '[WHATSAPP_WEB] fromMe=true detected, checking for recent duplicate (race condition protection)...'

      # Son 3 saniye içinde source_id'si olmayan outgoing mesaj var mı?
      # Bu, panel'den gönderilmiş ama source_id henüz kaydedilmemiş mesaj olabilir
      # NOT: İçerik kontrolü yapmıyoruz çünkü telefondan gönderilen mesajlar farklı içerikli olabilir
      three_seconds_ago = 3.seconds.ago
      recent_duplicate = @conversation.messages
                                      .where('created_at >= ?', three_seconds_ago)
                                      .where(message_type: :outgoing)
                                      .where(source_id: nil) # Sadece source_id'si olmayan mesajları kontrol et
                                      .order(created_at: :desc) # En yeni mesajı al
                                      .first

      if recent_duplicate
        Rails.logger.info "[WHATSAPP_WEB] ⚠️ KATMAN 3: Found recent duplicate (race condition): message_id=#{recent_duplicate.id}, content=#{recent_duplicate.content&.first(30)}"

        # Panel'den gönderilen mesajın source_id'sini güncelle (race condition fix)
        if message_source_id.present?
          recent_duplicate.update_column(:source_id, message_source_id)
          Rails.logger.info "[WHATSAPP_WEB] ✅ Updated recent message source_id: #{message_source_id}"
        end

        @message = recent_duplicate
        return
      end

      # fromMe=true ama duplicate yok → Bu mesaj DOĞRUDAN TELEFONDAN gönderilmiş
      Rails.logger.info '[WHATSAPP_WEB] ✅ fromMe=true but no duplicate found - this is a phone-sent message'
    end

    # Tüm kontroller geçildi → Yeni mesaj oluştur
    Rails.logger.info "[WHATSAPP_WEB] ✅ Creating new incoming message (fromMe=#{from_me})"

    # For vCard messages, don't set content (will be shown as contact bubble)
    # Also check if body contains vCard data even if vcards array is not present
    has_vcard_in_body = message_data[:body].to_s.include?('BEGIN:VCARD')
    message_content = if message_data[:vcards].present? || has_vcard_in_body
                        nil
                      else
                        message_data[:body] || message_data[:caption]
                      end

    @message = @conversation.messages.create!(
      content: message_content,
      account_id: channel.account_id,
      inbox_id: channel.inbox.id,
      message_type: from_me ? :outgoing : :incoming,
      sender: from_me ? outgoing_sender : @contact,
      source_id: message_source_id,
      content_type: determine_content_type
    )

    Rails.logger.info "[WHATSAPP_WEB] ✅ Created message: ID=#{@message.id}, type=#{@message.message_type}, source_id=#{message_source_id}, from=#{message_data[:from]}, to=#{message_data[:to]}, fromMe=#{from_me}"
  end

  def attach_files
    message_data[:attachments].each do |attachment_data|
      attachment = @message.attachments.new(
        account_id: channel.account_id,
        file_type: determine_file_type(attachment_data[:mimetype])
      )

      # Handle base64 data from WhatsApp Web
      if attachment_data[:data].present?
        attach_from_base64(attachment, attachment_data)
      # Handle URL if provided (for other sources)
      elsif attachment_data[:url].present?
        attachment.external_url = attachment_data[:url]
        download_and_attach_file(attachment, attachment_data)
      end

      attachment.save!
    end
  end

  def attach_from_base64(attachment, attachment_data)
    Rails.logger.info "[WHATSAPP_WEB] 📎 Processing base64 attachment: mimetype=#{attachment_data[:mimetype]}, filename=#{attachment_data[:filename]}"
    
    # WhatsApp Web.js returns base64 data, decode it
    base64_data = attachment_data[:data].to_s
    
    # Remove data URL prefix if present (e.g., "data:image/jpeg;base64,")
    base64_data = base64_data.sub(/^data:[^;]+;base64,/, '')
    
    # Decode base64 data
    decoded_data = Base64.decode64(base64_data)
    
    Rails.logger.info "[WHATSAPP_WEB] 📎 Decoded data size: #{decoded_data.bytesize} bytes"
    
    # Create a temporary file-like object
    file = StringIO.new(decoded_data)
    
    # Determine filename
    filename = attachment_data[:filename] || generate_filename(attachment_data[:mimetype])
    
    # Attach file
    attachment.file.attach(
      io: file,
      filename: filename,
      content_type: attachment_data[:mimetype] || 'application/octet-stream'
    )
    
    Rails.logger.info "[WHATSAPP_WEB] ✅ Attached file from base64: #{filename}, mimetype: #{attachment_data[:mimetype]}, size: #{decoded_data.bytesize} bytes"
  rescue StandardError => e
    Rails.logger.error "[WHATSAPP_WEB] ❌ Base64 attachment error: #{e.class.name}: #{e.message}"
    Rails.logger.error "[WHATSAPP_WEB] Backtrace: #{e.backtrace.first(10).join("\n")}"
    raise
  end

  def download_and_attach_file(attachment, attachment_data)
    file = Down.download(attachment_data[:url])
    attachment.file.attach(
      io: file,
      filename: attachment_data[:filename] || file.original_filename,
      content_type: attachment_data[:mimetype] || file.content_type
    )
  rescue StandardError => e
    Rails.logger.error "[WHATSAPP_WEB] File download error: #{e.message}"
  end

  def generate_filename(mimetype)
    extension = case mimetype
                when /^image\//
                  mimetype.split('/').last
                when /^video\//
                  mimetype.split('/').last
                when /^audio\//
                  mimetype.split('/').last
                else
                  'bin'
                end
    "whatsapp_media_#{Time.current.to_i}.#{extension}"
  end

  def normalize_phone_number(phone)
    Rails.logger.info "[WHATSAPP_WEB] Normalizing phone: #{phone.inspect}"

    return nil if phone.blank?

    original_phone = phone.to_s.dup

    # Group messages are already filtered out, so we only process individual messages
    # Normalize to E.164 format
    # Remove WhatsApp suffixes (@s.whatsapp.net, @c.us, etc.)
    phone = phone.to_s.gsub(/@[^.]+\.(whatsapp\.net|c\.us)/, '')
    Rails.logger.info "[WHATSAPP_WEB] After removing suffix: #{phone}"

    # Remove any remaining non-digit characters except +
    phone = phone.gsub(/[^\d+]/, '')
    Rails.logger.info "[WHATSAPP_WEB] After removing non-digits: #{phone}"

    # Ensure phone number starts with +
    phone = phone.start_with?('+') ? phone : "+#{phone}"
    Rails.logger.info "[WHATSAPP_WEB] After adding +: #{phone}"

    # Validate E.164 format (should start with + and contain only digits after)
    unless phone.match?(/^\+\d{1,15}$/)
      Rails.logger.error "[WHATSAPP_WEB] ❌ Invalid E.164 format: #{phone} (original: #{original_phone})"
      return nil
    end

    Rails.logger.info "[WHATSAPP_WEB] ✅ Final normalized phone: #{phone} (original: #{original_phone})"
    phone
  end

  def normalized_counterpart_number
    raw_number = if message_originates_from_channel?
                   message_data[:to]
                 else
                   message_data[:from]
                 end

    Rails.logger.info "[WHATSAPP_WEB] Determined raw counterpart number: #{raw_number}"
    normalize_phone_number(raw_number)
  end

  def message_originates_from_channel?
    message_data[:fromMe] == true || message_data[:fromMe].to_s == 'true'
  end

  def outgoing_sender
    @outgoing_sender ||= channel.account.users.order(:id).first
  end

  def determine_content_type
    # Message content_type is always 'text' for WhatsApp Web
    # Media files are handled as attachments, not content_type
    # Valid content_type values: text, input_text, input_textarea, input_email, 
    # input_select, cards, form, article, incoming_email, input_csat, 
    # integrations, sticker, voice_call
    'text'
  end

  def determine_file_type(mimetype)
    return :image if mimetype&.start_with?('image/')
    return :audio if mimetype&.start_with?('audio/')
    return :video if mimetype&.start_with?('video/')

    :file
  end

  def parse_vcard_from_body
    vcard_string = message_data[:body].to_s
    return unless vcard_string.include?('BEGIN:VCARD')

    # Parse vCard string
    display_name = ''
    first_name = ''
    last_name = ''
    phone_number = ''

    vcard_string.split(/\r?\n/).each do |line|
      upper_line = line.upcase
      
      # Extract FN (Full Name)
      if upper_line.start_with?('FN:')
        display_name = line[3..-1].to_s.strip
      end
      
      # Extract N (Name - structured)
      if upper_line.start_with?('N:')
        name_parts = line[2..-1].to_s.split(';')
        last_name = (name_parts[0] || '').strip
        first_name = (name_parts[1] || '').strip
      end
      
      # Extract TEL (Phone Number)
      if upper_line.start_with?('TEL')
        tel_match = line.match(/TEL[^:]*:(.+)/i)
        if tel_match
          phone = tel_match[1].to_s.strip
          phone_number = phone.gsub(/[^\d+]/, '')
        end
      end
    end

    # Use display name if first/last name are empty
    if first_name.blank? && last_name.blank? && display_name.present?
      name_parts = display_name.split(/\s+/)
      first_name = name_parts[0] || ''
      last_name = name_parts[1..-1].join(' ') || ''
    end

    # Ensure phone number starts with +
    phone_number = phone_number.start_with?('+') ? phone_number : "+#{phone_number}" if phone_number.present?

    # Add to vcards array
    message_data[:vcards] ||= []
    message_data[:vcards] << {
      displayName: display_name,
      firstName: first_name,
      lastName: last_name,
      phoneNumber: phone_number,
      vcard: vcard_string
    }

    Rails.logger.info "[WHATSAPP_WEB] 📇 Parsed vCard from body: name=#{display_name}, phone=#{phone_number}"
  end

  def attach_contacts
    message_data[:vcards].each do |vcard_data|
      # Extract contact information from vCard
      display_name = vcard_data[:displayName] || vcard_data['displayName'] || ''
      first_name = vcard_data[:firstName] || vcard_data['firstName'] || ''
      last_name = vcard_data[:lastName] || vcard_data['lastName'] || ''
      phone_number = vcard_data[:phoneNumber] || vcard_data['phoneNumber'] || ''
      
      # Parse phone number from vCard string if not provided
      if phone_number.blank? && vcard_data[:vcard].present?
        vcard_string = vcard_data[:vcard] || vcard_data['vcard']
        phone_match = vcard_string.match(/TEL[^:]*:(.+)/i)
        if phone_match
          phone_number = phone_match[1].to_s.gsub(/[^\d+]/, '')
        end
      end
      
      # Use display name if first/last name are empty
      if first_name.blank? && last_name.blank? && display_name.present?
        name_parts = display_name.split(/\s+/)
        first_name = name_parts[0] || ''
        last_name = name_parts[1..-1].join(' ') || ''
      end
      
      # Ensure phone number starts with +
      phone_number = phone_number.start_with?('+') ? phone_number : "+#{phone_number}" if phone_number.present?
      
      Rails.logger.info "[WHATSAPP_WEB] 📇 Attaching contact: name=#{display_name}, phone=#{phone_number}"
      
      @message.attachments.create!(
        account_id: channel.account_id,
        file_type: :contact,
        fallback_title: phone_number.presence || display_name.presence || 'Contact',
        meta: {
          firstName: first_name,
          lastName: last_name
        }.compact
      )
    end
  rescue StandardError => e
    Rails.logger.error "[WHATSAPP_WEB] ❌ Contact attachment error: #{e.class.name}: #{e.message}"
    Rails.logger.error "[WHATSAPP_WEB] Backtrace: #{e.backtrace.first(10).join("\n")}"
    raise
  end

  def conversation_params
    {
      account_id: channel.account_id,
      inbox_id: channel.inbox.id,
      contact_id: @contact.id,
      contact_inbox_id: @contact_inbox.id,
      status: :open
    }
  end
end
