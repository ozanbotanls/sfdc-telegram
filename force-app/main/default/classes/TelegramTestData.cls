/**
 * Captured-shape Telegram update payloads.
 *
 * The ids are deliberately above 2^31 -- that is the regression these fixtures
 * exist for, since the parser used to cast them to Integer.
 */
@IsTest
public class TelegramTestData {
    public static final String BIG_USER_ID = '7123456789';
    public static final String GROUP_CHAT_ID = '-1001234567890';
    public static final String BIG_UPDATE_ID = '2147483648';

    public static String privateText() {
        return message('"text": "hello bot"', privateChat());
    }

    public static String groupText() {
        return message('"text": "hello bot"', groupChat());
    }

    public static String photo() {
        return message('"photo": [{ "file_id": "AgACAgQ", "width": 90, "height": 90 }]', privateChat());
    }

    public static String sticker() {
        return message('"sticker": { "file_id": "CAACAgIA", "emoji": "\\uD83D\\uDE00" }', privateChat());
    }

    public static String voice() {
        return message('"voice": { "file_id": "AwACAgQ", "duration": 3 }', privateChat());
    }

    public static String audio() {
        return message('"audio": { "file_id": "CQACAgQ", "duration": 120 }', privateChat());
    }

    public static String document() {
        return message('"document": { "file_id": "BQACAgQ", "file_name": "report.pdf" }', privateChat());
    }

    /** Telegram sends `document` alongside `animation`; animation must win. */
    public static String animation() {
        return message('"animation": { "file_id": "CgACAgQ" }, "document": { "file_id": "CgACAgQ" }', privateChat());
    }

    /** A message sub-type the connector does not model. */
    public static String unsupported() {
        return message('"poll": { "id": "1", "question": "?" }', privateChat());
    }

    public static String callbackQuery() {
        return '{' +
            '"update_id": ' +
            BIG_UPDATE_ID +
            ',' +
            '"callback_query": {' +
            '  "id": "4382bfdwdsb323b2d9",' +
            '  "from": ' +
            sender() +
            ',' +
            '  "message": { "message_id": 1234, "chat": ' +
            groupChat() +
            ' },' +
            '  "data": "keyboard1"' +
            '}}';
    }

    public static String inlineQuery() {
        return '{' +
            '"update_id": ' +
            BIG_UPDATE_ID +
            ',' +
            '"inline_query": {' +
            '  "id": "1234567890123456789",' +
            '  "from": ' +
            sender() +
            ',' +
            '  "query": "order status",' +
            '  "chat_type": "sender"' +
            '}}';
    }

    public static String channelPost() {
        return '{' +
            '"update_id": ' +
            BIG_UPDATE_ID +
            ',' +
            '"channel_post": { "message_id": 55, "text": "broadcast", "chat": ' +
            channelChat() +
            ' }' +
            '}';
    }

    private static String message(String entityJson, String chatJson) {
        return '{' +
            '"update_id": ' +
            BIG_UPDATE_ID +
            ',' +
            '"message": {' +
            '  "message_id": 9876543210,' +
            '  "from": ' +
            sender() +
            ',' +
            '  "chat": ' +
            chatJson +
            ',' +
            '  "date": 1700000000,' +
            entityJson +
            '}}';
    }

    private static String sender() {
        return '{ "id": ' +
            BIG_USER_ID +
            ', "is_bot": false, "first_name": "Ada", ' +
            '"last_name": "Lovelace", "username": "ada" }';
    }

    private static String privateChat() {
        return '{ "id": ' + BIG_USER_ID + ', "type": "private", "username": "ada" }';
    }

    private static String groupChat() {
        return '{ "id": ' + GROUP_CHAT_ID + ', "type": "supergroup", "title": "Support Team" }';
    }

    private static String channelChat() {
        return '{ "id": ' + GROUP_CHAT_ID + ', "type": "channel", "title": "Announcements" }';
    }
}
