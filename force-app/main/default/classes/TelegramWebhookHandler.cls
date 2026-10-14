/**
 * Implement this and name the class in Telegram Setup custom metadata
 * (Handler_Class__c) to receive parsed Telegram updates from TelegramWebhook.
 *
 * Implementations must have a public no-argument constructor.
 */
public interface TelegramWebhookHandler {
    /**
     * @param update an already-parsed update. Reply with
     *               update.getChatId() -- never update.getSender().id, which
     *               differs in groups, supergroups and channels.
     */
    void handleUpdate(TelegramMessageParser update);
}
