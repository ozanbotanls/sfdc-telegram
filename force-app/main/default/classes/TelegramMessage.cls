public with sharing abstract class TelegramMessage {
    protected Template telegramTemplate;
    public TelegramMessage() {
        this.telegramTemplate = new Template();
    }

    public TelegramMessage addInlineKeyboard(List<Telegram.InlineKeyboard> inlineKeyboardMarkup) {
        if (!inlineKeyboardMarkup.isEmpty()) {
            List<List<Telegram.InlineKeyboard>> nestedInlineList = new List<List<Telegram.InlineKeyboard>>();
            for (Telegram.InlineKeyboard keyboard : inlineKeyboardMarkup) {
                nestedInlineList.add(new List<Telegram.InlineKeyboard>{ keyboard });
            }
            this.telegramTemplate.reply_markup = new Map<String, List<List<Telegram.InlineKeyboard>>>{
                'inline_keyboard' => nestedInlineList
            };
        }
        return this;
    }

    public TelegramMessage addReplyKeyboard(
        List<Telegram.ReplyKeyboard> replyKeyboardMarkup,
        Boolean resizeKeyboard,
        Boolean isOneTime
    ) {
        if (!replyKeyboardMarkup.isEmpty()) {
            List<List<Telegram.ReplyKeyboard>> nestedReplyList = new List<List<Telegram.ReplyKeyboard>>();
            for (Telegram.ReplyKeyboard keyboard : replyKeyboardMarkup) {
                nestedReplyList.add(new List<Telegram.ReplyKeyboard>{ keyboard });
            }
            this.telegramTemplate.reply_markup = new Map<String, Object>{
                'keyboard' => nestedReplyList,
                'resize_keyboard' => resizeKeyboard,
                'one_time_keyboard' => isOneTime
            };
        }
        return this;
    }

    public TelegramMessage removeReplyKeyboard() {
        this.telegramTemplate.reply_markup = JSON.deserializeUntyped('{ "remove_keyboard": true }');
        return this;
    }

    public TelegramMessage forceReply() {
        this.telegramTemplate.reply_markup = JSON.deserializeUntyped('{ "force_reply": true }');
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
        final List<String> AVAILABLE_TYPES = new List<String>{
            'typing',
            'upload_photo',
            'record_video',
            'upload_video',
            'record_audio',
            'upload_audio',
            'upload_document',
            'find_location'
        };
        public ChatAction(String action) {
            super();
            if (!AVAILABLE_TYPES.contains(action)) {
                // ERROR HANDLING HERE
                return;
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
        Object reply_markup;
    }

    public class TelegramTemplate {
        Template template;
        String method;
        TelegramTemplate(Template template, String method) {
            this.template = template;
            this.method = method;
        }
        public String sendMessage(String chatId, Boolean isImmediate) {
            if (this.template.chat_id == null) {
                this.template.chat_id = chatId;
            }
            return TelegramUtility.sendMessage(getTemplateString(), this.method, isImmediate);
        }
        public String getTemplateString() {
            return JSON.serialize(this.template, true);
        }
    }
}