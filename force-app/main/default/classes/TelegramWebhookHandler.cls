/**
 * Implement this and name the class in Telegram Setup custom metadata
 * (Handler_Class__c) to receive parsed Telegram updates from TelegramWebhook.
 *
 * Implementations must have a public no-argument constructor.
 */
public interface TelegramWebhookHandler {
    /**
     * @param telegramUpdate an already-parsed update ("update" alone is a reserved DML keyword). Reply with
     *               telegramUpdate.getChatId() -- never telegramUpdate.getSender().id, which
     *               differs in groups, supergroups and channels.
     */
    void handleUpdate(TelegramMessageParser telegramUpdate);
}
