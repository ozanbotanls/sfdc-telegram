public with sharing abstract class TelegramMessage {
    // https://core.telegram.org/bots/api#sendchataction
    // Declared on the outer class: Apex does not allow static members on inner classes.
    public static final Set<String> AVAILABLE_CHAT_ACTIONS = new Set<String>{
        'typing',
        'upload_photo',
        'record_video',
        'upload_video',
        'record_audio',
        'upload_audio',
        'upload_document',
        'find_location',
        'record_video_note',
        'upload_video_note',
        'choose_sticker'
    };

    protected Template telegramTemplate;
    public TelegramMessage() {
        this.telegramTemplate = new Template();
    }

    /**
     * Stacks every button in its own row. Kept for backward compatibility --
     * pass a List<List<Telegram.InlineKeyboard>> to lay buttons out side by side.
     */
    public TelegramMessage addInlineKeyboard(List<Telegram.InlineKeyboard> inlineKeyboardMarkup) {
        if (inlineKeyboardMarkup == null || inlineKeyboardMarkup.isEmpty()) {
            return this;
        }
        List<List<Telegram.InlineKeyboard>> nestedInlineList = new List<List<Telegram.InlineKeyboard>>();
        for (Telegram.InlineKeyboard keyboard : inlineKeyboardMarkup) {
            nestedInlineList.add(new List<Telegram.InlineKeyboard>{ keyboard });
        }
        return addInlineKeyboard(nestedInlineList);
    }

    /** One inner list per keyboard row, so several buttons can share a row. */
    public TelegramMessage addInlineKeyboard(List<List<Telegram.InlineKeyboard>> inlineKeyboardRows) {
        if (inlineKeyboardRows == null || inlineKeyboardRows.isEmpty()) {
            return this;
        }
        this.telegramTemplate.reply_markup = new Map<String, Object>{ 'inline_keyboard' => inlineKeyboardRows };
        return this;
    }

    /**
     * Stacks every button in its own row. Kept for backward compatibility --
     * pass a List<List<Telegram.ReplyKeyboard>> to lay buttons out side by side.
     */
    public TelegramMessage addReplyKeyboard(
        List<Telegram.ReplyKeyboard> replyKeyboardMarkup,
        Boolean resizeKeyboard,
        Boolean isOneTime
    ) {
        if (replyKeyboardMarkup == null || replyKeyboardMarkup.isEmpty()) {
            return this;
        }
        List<List<Telegram.ReplyKeyboard>> nestedReplyList = new List<List<Telegram.ReplyKeyboard>>();
        for (Telegram.ReplyKeyboard keyboard : replyKeyboardMarkup) {
            nestedReplyList.add(new List<Telegram.ReplyKeyboard>{ keyboard });
        }
        return addReplyKeyboard(nestedReplyList, resizeKeyboard, isOneTime);
    }

    /** One inner list per keyboard row, so several buttons can share a row. */
    public TelegramMessage addReplyKeyboard(
        List<List<Telegram.ReplyKeyboard>> replyKeyboardRows,
        Boolean resizeKeyboard,
        Boolean isOneTime
    ) {
        if (replyKeyboardRows == null || replyKeyboardRows.isEmpty()) {
            return this;
        }
        this.telegramTemplate.reply_markup = new Map<String, Object>{
            'keyboard' => replyKeyboardRows,
            'resize_keyboard' => resizeKeyboard,
            'one_time_keyboard' => isOneTime
        };
        return this;
    }

    public TelegramMessage removeReplyKeyboard() {
        this.telegramTemplate.reply_markup = new Map<String, Object>{ 'remove_keyboard' => true };
        return this;
    }

    public TelegramMessage forceReply() {
        this.telegramTemplate.reply_markup = new Map<String, Object>{ 'force_reply' => true };
        return this;
    }

    // this will be overridden by classes those are extending this class below.
    public abstract TelegramTemplate get();

    /**
     *  Telegram Message Types as inner classes
     *  to be used to build different types of messages.
     */
    public class Text extends TelegramMessage {
        public Text(String textMessage) {
            super();
            this.telegramTemplate.parse_mode = 'Markdown';
            this.telegramTemplate.text = textMessage;
        }
        public override TelegramTemplate get() {
            return new TelegramTemplate(this.telegramTemplate, 'sendMessage');
        }
    }

    public class Photo extends TelegramMessage {
        public Photo(String photo, String caption) {
            super();
            this.telegramTemplate.photo = photo;
            this.telegramTemplate.caption = caption;
        }
        public override TelegramTemplate get() {
            return new TelegramTemplate(this.telegramTemplate, 'sendPhoto');
        }
    }

    public class Sticker extends TelegramMessage {
        public Sticker(String sticker) {
            super();
            this.telegramTemplate.sticker = sticker;
        }
        public override TelegramTemplate get() {
            return new TelegramTemplate(this.telegramTemplate, 'sendSticker');
        }
    }

    public class ChatAction extends TelegramMessage {
        public ChatAction(String action) {
            super();
            if (!AVAILABLE_CHAT_ACTIONS.contains(action)) {
                // previously this returned silently, building a sendChatAction
                // payload with no action and guaranteeing a Telegram 400
                throw new TelegramException(
                    'Unsupported chat action "' + action + '". Expected one of: ' + AVAILABLE_CHAT_ACTIONS
                );
            }
            this.telegramTemplate.action = action;
        }
        public override TelegramTemplate get() {
            return new TelegramTemplate(this.telegramTemplate, 'sendChatAction');
        }
    }

    public class Location extends TelegramMessage {
        public Location(Decimal latitude, Decimal longitude) {
            super();
            this.telegramTemplate.latitude = latitude;
            this.telegramTemplate.longitude = longitude;
        }
        public override TelegramTemplate get() {
            return new TelegramTemplate(this.telegramTemplate, 'sendLocation');
        }
    }

    public class Contact extends TelegramMessage {
        public Contact(String phone, String firstName, String lastName) {
            super();
            this.telegramTemplate.phone_number = phone;
            this.telegramTemplate.first_name = firstName;
            this.telegramTemplate.last_name = lastName;
        }
        public override TelegramTemplate get() {
            return new TelegramTemplate(this.telegramTemplate, 'sendContact');
        }
    }

    /**
     * Telegram requires every callback_query to be answered, otherwise the
     * button the user tapped keeps spinning until the query times out.
     */
    public class AnswerCallbackQuery extends TelegramMessage {
        public AnswerCallbackQuery(String callbackQueryId, String text) {
            this(callbackQueryId, text, false);
        }
        public AnswerCallbackQuery(String callbackQueryId, String text, Boolean showAlert) {
            super();
            this.telegramTemplate.callback_query_id = callbackQueryId;
            this.telegramTemplate.text = text;
            this.telegramTemplate.show_alert = showAlert;
        }
        public override TelegramTemplate get() {
            return new TelegramTemplate(this.telegramTemplate, 'answerCallbackQuery', false);
        }
    }

    /**
     * @param results already-serialized JSON array of InlineQueryResult objects.
     *                See https://core.telegram.org/bots/api#inlinequeryresult
     */
    public class AnswerInlineQuery extends TelegramMessage {
        public AnswerInlineQuery(String inlineQueryId, String results) {
            super();
            this.telegramTemplate.inline_query_id = inlineQueryId;
            this.telegramTemplate.results = results;
        }
        public override TelegramTemplate get() {
            return new TelegramTemplate(this.telegramTemplate, 'answerInlineQuery', false);
        }
    }

    public class EditMessageText extends TelegramMessage {
        public EditMessageText(String messageId, String textMessage) {
            super();
            this.telegramTemplate.message_id = toMessageId(messageId);
            this.telegramTemplate.parse_mode = 'Markdown';
            this.telegramTemplate.text = textMessage;
        }
        public override TelegramTemplate get() {
            return new TelegramTemplate(this.telegramTemplate, 'editMessageText');
        }
    }

    public class DeleteMessage extends TelegramMessage {
        public DeleteMessage(String messageId) {
            super();
            this.telegramTemplate.message_id = toMessageId(messageId);
        }
        public override TelegramTemplate get() {
            return new TelegramTemplate(this.telegramTemplate, 'deleteMessage');
        }
    }

    /** Telegram documents message_id as an integer, unlike chat_id which may be a string. */
    private static Long toMessageId(String messageId) {
        if (String.isBlank(messageId)) {
            throw new TelegramException('A message id is required.');
        }
        try {
            return Long.valueOf(messageId);
        } catch (Exception e) {
            throw new TelegramException('Invalid message id "' + messageId + '".');
        }
    }

    // inner class to ground template upon.
    class Template {
        String chat_id;
        String text;
        String parse_mode;
        String photo;
        String caption;
        String sticker;
        String action;
        Decimal latitude;
        Decimal longitude;
        String phone_number;
        String first_name;
        String last_name;
        Long message_id;
        String callback_query_id;
        Boolean show_alert;
        String inline_query_id;
        String results;
        Object reply_markup;
    }

    public class TelegramTemplate {
        Template template;
        String method;
        /** answerCallbackQuery / answerInlineQuery are not addressed to a chat. */
        Boolean requiresChatId;
        TelegramTemplate(Template template, String method) {
            this(template, method, true);
        }
        TelegramTemplate(Template template, String method, Boolean requiresChatId) {
            this.template = template;
            this.method = method;
            this.requiresChatId = requiresChatId;
        }
        /**
         * @param chatId      where to deliver the message. In groups and channels this is
         *                    the chat id from TelegramMessageParser.getChatId(), NOT the
         *                    sender id. Ignored by methods that are not chat-addressed.
         * @param isImmediate true to call out synchronously and return the response body,
         *                    false to hand the callout to a Queueable and return null.
         */
        public String sendMessage(String chatId, Boolean isImmediate) {
            if (this.requiresChatId == true) {
                if (this.template.chat_id == null) {
                    this.template.chat_id = chatId;
                }
                if (String.isBlank(this.template.chat_id)) {
                    throw new TelegramException('A chat id is required for ' + this.method + '.');
                }
            }
            return TelegramUtility.sendMessage(getTemplateString(), this.method, isImmediate);
        }
        public String getTemplateString() {
            return JSON.serialize(this.template, true);
        }
    }
}
