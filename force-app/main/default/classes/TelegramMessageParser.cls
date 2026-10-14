public with sharing class TelegramMessageParser {
    /**
     * Keys that identify a message sub-type, in precedence order. Order matters:
     * Telegram sends `document` alongside `animation` for GIFs, so `animation`
     * has to win, and `video_note` has to be tested before `video`.
     */
    private static final List<String> ENTITY_KEYS = new List<String>{
        'animation',
        'photo',
        'sticker',
        'video_note',
        'video',
        'voice',
        'audio',
        'document',
        'location',
        'contact'
    };
    private static final Map<String, Telegram.EntityType> ENTITY_TYPE_BY_KEY = new Map<String, Telegram.EntityType>{
        'animation' => Telegram.EntityType.ANIMATION,
        'photo' => Telegram.EntityType.PHOTO,
        'sticker' => Telegram.EntityType.STICKER,
        'video_note' => Telegram.EntityType.VIDEO_NOTE,
        'video' => Telegram.EntityType.VIDEO,
        'voice' => Telegram.EntityType.VOICE,
        'audio' => Telegram.EntityType.AUDIO,
        'document' => Telegram.EntityType.DOCUMENT,
        'location' => Telegram.EntityType.LOCATION,
        'contact' => Telegram.EntityType.CONTACT
    };
    /** Update keys that carry a plain message payload. */
    private static final List<String> MESSAGE_KEYS = new List<String>{
        'message',
        'edited_message',
        'channel_post',
        'edited_channel_post'
    };

    private String updateId, messageId, text, callbackMessageId;
    private Boolean isCallback, isInline, isMessage;
    private Telegram.Entity entity;
    private Telegram.TelegramUser fromUser;
    private Telegram.Chat chat;
    private Map<String, Object> telegramPayload;

    public TelegramMessageParser(String payload) {
        this.telegramPayload = (Map<String, Object>) JSON.deserializeUntyped(payload);
        this.isCallback = telegramPayload.containsKey('callback_query');
        this.isInline = telegramPayload.containsKey('inline_query');
        this.isMessage = false;
        for (String key : MESSAGE_KEYS) {
            if (telegramPayload.containsKey(key)) {
                this.isMessage = true;
                break;
            }
        }
        this.updateId = asId(telegramPayload.get('update_id'));
    }

    public TelegramMessageParser parse() {
        // callbackquery update
        if (this.isCallback) {
            Map<String, Object> callbackQuery = (Map<String, Object>) telegramPayload.get('callback_query');
            this.messageId = (String) callbackQuery.get('id');
            this.text = (String) callbackQuery.get('data');
            this.fromUser = buildUser((Map<String, Object>) callbackQuery.get('from'));
            // the message the inline keyboard was attached to; absent for inline-mode callbacks
            Map<String, Object> callbackMessage = (Map<String, Object>) callbackQuery.get('message');
            if (callbackMessage != null) {
                this.callbackMessageId = asId(callbackMessage.get('message_id'));
                this.chat = buildChat((Map<String, Object>) callbackMessage.get('chat'));
            }
        }
        // inlinequery update
        if (this.isInline) {
            Map<String, Object> inlineQuery = (Map<String, Object>) telegramPayload.get('inline_query');
            this.messageId = (String) inlineQuery.get('id');
            this.text = (String) inlineQuery.get('query');
            this.fromUser = buildUser((Map<String, Object>) inlineQuery.get('from'));
            // inline queries carry no chat, so answer the sender directly
            this.chat = buildChatFromSender(this.fromUser, (String) inlineQuery.get('chat_type'));
        }
        // none of them. just a regular message type of text, photo, sticker, audio, etc.
        if (this.isMessage) {
            Map<String, Object> messageMap = getMessageMap();
            this.messageId = asId(messageMap.get('message_id'));
            this.text = messageMap.containsKey('text') ? (String) messageMap.get('text') : '';
            this.fromUser = buildUser((Map<String, Object>) messageMap.get('from'));
            this.chat = buildChat((Map<String, Object>) messageMap.get('chat'));
            this.entity = !String.isBlank(this.text)
                ? new Telegram.Entity(this.text, Telegram.EntityType.TEXT)
                : buildEntity(messageMap);
        }
        // a chat is always preferable, but fall back to the sender so callers
        // reading getChatId() on an unusual update still get something routable
        if (this.chat == null && this.fromUser != null) {
            this.chat = buildChatFromSender(this.fromUser, null);
        }
        return this;
    }

    private Map<String, Object> getMessageMap() {
        for (String key : MESSAGE_KEYS) {
            if (telegramPayload.containsKey(key)) {
                return (Map<String, Object>) telegramPayload.get(key);
            }
        }
        return new Map<String, Object>();
    }

    // in case the incoming message is type OF MESSAGE, identify its sub-type
    private Telegram.Entity buildEntity(Map<String, Object> message) {
        for (String key : ENTITY_KEYS) {
            if (message.containsKey(key)) {
                return new Telegram.Entity(message.get(key), ENTITY_TYPE_BY_KEY.get(key));
            }
        }
        // never return null -- callers should get a usable entity for any update
        return new Telegram.Entity(null, Telegram.EntityType.UNKNOWN);
    }

    private Telegram.TelegramUser buildUser(Map<String, Object> sender) {
        if (sender == null) {
            return null;
        }
        Telegram.TelegramUser telegramUser = new Telegram.TelegramUser();
        telegramUser.id = asId(sender.get('id'));
        telegramUser.first_name = (String) sender.get('first_name');
        telegramUser.last_name = (String) sender.get('last_name');
        telegramUser.username = (String) sender.get('username');
        telegramUser.is_bot = (Boolean) sender.get('is_bot');
        return telegramUser;
    }

    private Telegram.Chat buildChat(Map<String, Object> chatMap) {
        if (chatMap == null) {
            return null;
        }
        Telegram.Chat telegramChat = new Telegram.Chat();
        telegramChat.id = asId(chatMap.get('id'));
        telegramChat.type = (String) chatMap.get('type');
        telegramChat.title = (String) chatMap.get('title');
        telegramChat.username = (String) chatMap.get('username');
        return telegramChat;
    }

    private Telegram.Chat buildChatFromSender(Telegram.TelegramUser sender, String chatType) {
        Telegram.Chat telegramChat = new Telegram.Chat();
        telegramChat.id = sender.id;
        telegramChat.type = String.isBlank(chatType) ? 'private' : chatType;
        telegramChat.username = sender.username;
        return telegramChat;
    }

    /**
     * Telegram ids are 64-bit. Casting them to Integer throws a TypeException for
     * any id above 2^31 -- which is most modern user ids, and every supergroup
     * chat id (e.g. -1001234567890). Stringify the raw value instead.
     */
    private static String asId(Object value) {
        return value == null ? null : String.valueOf(value);
    }

    // APIs to expose class variables.
    public Telegram.TelegramUser getSender() {
        return this.fromUser;
    }
    public Telegram.Chat getChat() {
        return this.chat;
    }
    /** The id to send replies to. In groups and channels this is NOT the sender id. */
    public String getChatId() {
        return this.chat == null ? null : this.chat.id;
    }
    public String getChatType() {
        return this.chat == null ? null : this.chat.type;
    }
    public String getMessage() {
        return this.text;
    }
    public String getMessageId() {
        return this.messageId;
    }
    /** The id of the message an inline keyboard was attached to, for editMessageText/deleteMessage. */
    public String getCallbackMessageId() {
        return this.callbackMessageId;
    }
    public String getUpdateId() {
        return this.updateId;
    }
    public Object getEntity() {
        return this.entity == null ? null : this.entity.getEntity();
    }
    public Telegram.EntityType getEntityType() {
        return this.entity == null ? null : this.entity.getType();
    }
    public Boolean isCallback() {
        return this.isCallback;
    }
    public Boolean isInline() {
        return this.isInline;
    }
    public Boolean isMessage() {
        return this.isMessage;
    }
    private Boolean isEntityType(Telegram.EntityType type) {
        return this.entity != null && this.entity.getType() == type;
    }
    public Boolean isText() {
        return isEntityType(Telegram.EntityType.TEXT);
    }
    public Boolean isPhoto() {
        return isEntityType(Telegram.EntityType.PHOTO);
    }
    public Boolean isSticker() {
        return isEntityType(Telegram.EntityType.STICKER);
    }
    public Boolean isVoice() {
        return isEntityType(Telegram.EntityType.VOICE);
    }
    public Boolean isAudio() {
        return isEntityType(Telegram.EntityType.AUDIO);
    }
    public Boolean isDocument() {
        return isEntityType(Telegram.EntityType.DOCUMENT);
    }
    public Boolean isVideo() {
        return isEntityType(Telegram.EntityType.VIDEO);
    }
    public Boolean isVideoNote() {
        return isEntityType(Telegram.EntityType.VIDEO_NOTE);
    }
    public Boolean isAnimation() {
        return isEntityType(Telegram.EntityType.ANIMATION);
    }
    public Boolean isLocation() {
        return isEntityType(Telegram.EntityType.LOCATION);
    }
    public Boolean isContact() {
        return isEntityType(Telegram.EntityType.CONTACT);
    }
}
