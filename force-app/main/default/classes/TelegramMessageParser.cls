public with sharing class TelegramMessageParser {
    private String updateId, messageId, text;
    private Boolean isCallback, isInline, isMessage;
    private Telegram.Entity entity;
    private Telegram.TelegramUser fromUser;
    private Map<String, Object> telegramPayload;

    public TelegramMessageParser(String payload) {
        this.telegramPayload = (Map<String, Object>) JSON.deserializeUntyped(payload);
        this.isCallback = telegramPayload.containsKey('callback_query');
        this.isInline = telegramPayload.containsKey('inline_query');
        this.isMessage = telegramPayload.containsKey('message');
        this.updateId = String.valueOf((Integer) telegramPayload.get('update_id'));
    }

    public TelegramMessageParser parse() {
        // callbackquery update
        if (this.isCallback) {
            Map<String, Object> callbackQuery = (Map<String, Object>) telegramPayload.get('callback_query');
            this.messageId = (String) callbackQuery.get('id');
            this.text = (String) callbackQuery.get('data');
            this.fromUser = buildUser((Map<String, Object>) callbackQuery.get('from'));
        }
        // inlinequery update
        if (this.isInline) {
            Map<String, Object> inlineQuery = (Map<String, Object>) telegramPayload.get('inline_query');
            this.messageId = (String) inlineQuery.get('id');
            this.text = (String) inlineQuery.get('query');
            this.fromUser = buildUser((Map<String, Object>) inlineQuery.get('from'));
        }
        // none of them. just a regular message type of text, photo, sticker, audio, etc.
        if (this.isMessage) {
            Map<String, Object> messageMap = (Map<String, Object>) telegramPayload.get('message');
            this.messageId = String.valueOf((Integer) messageMap.get('message_id'));
            this.text = messageMap.containsKey('text') ? (String) messageMap.get('text') : '';
            this.fromUser = buildUser((Map<String, Object>) messageMap.get('from'));
            this.entity = !String.isBlank(this.text)
                ? new Telegram.Entity(this.text, Telegram.EntityType.Text)
                : buildEntity(messageMap);
        }
        return this;
    }

    // in case the incoming message is type OF MESSAGE, identify its sub-type
    private Telegram.Entity buildEntity(Map<String, Object> message) {
        Telegram.Entity entity;
        entity = message.containsKey('photo')
            ? new Telegram.Entity(message.get('photo'), Telegram.EntityType.PHOTO)
            : null;
        entity = entity == null && message.containsKey('sticker')
            ? new Telegram.Entity(message.get('sticker'), Telegram.EntityType.STICKER)
            : null;
        entity = entity == null && message.containsKey('voice')
            ? new Telegram.Entity(message.get('voice'), Telegram.EntityType.VOICE)
            : null;
        entity = entity == null && message.containsKey('audio')
            ? new Telegram.Entity(message.get('audio'), Telegram.EntityType.AUDIO)
            : null;
        return entity;
    }

    private Telegram.TelegramUser buildUser(Map<String, Object> sender) {
        Telegram.TelegramUser telegramUser = new Telegram.TelegramUser();
        telegramUser.id = String.valueOf((Integer) sender.get('id'));
        telegramUser.first_name = (String) sender.get('first_name');
        telegramUser.last_name = (String) sender.get('last_name');
        telegramUser.username = (String) sender.get('username');
        telegramUser.is_bot = (Boolean) sender.get('is_bot');
        return telegramUser;
    }

    // APIs to expose class variables.
    public Telegram.TelegramUser getSender() {
        return this.fromUser;
    }
    public String getMessage() {
        return this.text;
    }
    public String getMessageId() {
        return this.messageId;
    }
    public String getUpdateId() {
        return this.updateId;
    }
    public Object getEntity() {
        return this.entity.getEntity();
    }
    public Boolean isCallback() {
        return this.isCallback;
    }
    public Boolean isInline() {
        return this.isInline;
    }
    public Boolean isText() {
        return this.entity.getType() == Telegram.EntityType.TEXT;
    }
    public Boolean isPhoto() {
        return this.entity.getType() == Telegram.EntityType.PHOTO;
    }
    public Boolean isSticker() {
        return this.entity.getType() == Telegram.EntityType.STICKER;
    }
    public Boolean isVoice() {
        return this.entity.getType() == Telegram.EntityType.VOICE;
    }
    public Boolean isAudio() {
        return this.entity.getType() == Telegram.EntityType.AUDIO;
    }
}