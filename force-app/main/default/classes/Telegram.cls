public class Telegram {
    /* ========================================
     * Wrapper classes to be used for GENERATING Telegram payload
     * They will be used in HTTP request from SFDC to Telegram
     * =======================================*/
    // https://core.telegram.org/bots/api/#inlinekeyboardbutton
    public class InlineKeyboard {
        public String text;
        public String callback_data;
        public String url;
    }
    // https://core.telegram.org/bots/api/#keyboardbutton
    public class ReplyKeyboard {
        public String text;
    }
    /* ========================================
     * Wrapper classes to be used for PARSING Telegram payload
     * They will be used in APIs from Telegram to SFDC
     * =======================================*/
    // https://core.telegram.org/bots/api/#user
    public class TelegramUser {
        public String id;
        public String first_name;
        public String last_name;
        public String username;
        public Boolean is_bot;
    }
    public class Entity {
        Object entity;
        EntityType type;
        public Entity(Object entity, EntityType type) {
            this.entity = entity;
            this.type = type;
        }
        public EntityType getType() {
            return this.type;
        }
        public Object getEntity() {
            return this.entity;
        }
    }
    public enum EntityType {
        TEXT,
        PHOTO,
        AUDIO,
        STICKER,
        VOICE
    }
}