@IsTest
private class TelegramMessageTest {
    private static final String CHAT_ID = '-1001234567890';

    private static Map<String, Object> payloadOf(TelegramMessage.TelegramTemplate template) {
        return (Map<String, Object>) JSON.deserializeUntyped(template.getTemplateString());
    }

    @IsTest
    static void buildsEachMessageType() {
        Assert.areEqual('hi', payloadOf(new TelegramMessage.Text('hi').get()).get('text'));
        Assert.areEqual('cap', payloadOf(new TelegramMessage.Photo('url', 'cap').get()).get('caption'));
        Assert.areEqual('sid', payloadOf(new TelegramMessage.Sticker('sid').get()).get('sticker'));
        Assert.areEqual('typing', payloadOf(new TelegramMessage.ChatAction('typing').get()).get('action'));
        Assert.areEqual(12.5, payloadOf(new TelegramMessage.Location(12.5, 20.5).get()).get('latitude'));
        Assert.areEqual(
            '+123',
            payloadOf(new TelegramMessage.Contact('+123', 'Ada', 'Lovelace').get()).get('phone_number')
        );
    }

    /** Regression: an unsupported action silently produced a payload with no action. */
    @IsTest
    static void rejectsUnsupportedChatAction() {
        try {
            new TelegramMessage.ChatAction('interpretive_dance');
            Assert.fail('an unsupported chat action should throw');
        } catch (TelegramException e) {
            Assert.isTrue(e.getMessage().contains('interpretive_dance'));
        }
    }

    /** A flat list keeps its old behaviour: one button per row. */
    @IsTest
    static void flatInlineKeyboardStacksOneButtonPerRow() {
        List<Object> rows = inlineRowsOf(
            new TelegramMessage.Text('q')
                .addInlineKeyboard(new List<Telegram.InlineKeyboard>{ button('a'), button('b') })
        );

        Assert.areEqual(2, rows.size(), 'two rows');
        Assert.areEqual(1, ((List<Object>) rows[0]).size(), 'one button in the first row');
    }

    /** Regression: a row of side-by-side buttons was previously not expressible. */
    @IsTest
    static void nestedInlineKeyboardKeepsButtonsOnOneRow() {
        List<Object> rows = inlineRowsOf(
            new TelegramMessage.Text('q')
                .addInlineKeyboard(
                    new List<List<Telegram.InlineKeyboard>>{
                        new List<Telegram.InlineKeyboard>{ button('a'), button('b') },
                        new List<Telegram.InlineKeyboard>{ button('c') }
                    }
                )
        );

        Assert.areEqual(2, rows.size(), 'two rows');
        Assert.areEqual(2, ((List<Object>) rows[0]).size(), 'two buttons share the first row');
        Assert.areEqual(1, ((List<Object>) rows[1]).size());
    }

    @IsTest
    static void replyKeyboardSupportsRowsAndOptions() {
        Telegram.ReplyKeyboard key = new Telegram.ReplyKeyboard();
        key.text = 'Open a Case';
        Map<String, Object> markup = (Map<String, Object>) payloadOf(
                new TelegramMessage.Text('q')
                    .addReplyKeyboard(
                        new List<List<Telegram.ReplyKeyboard>>{ new List<Telegram.ReplyKeyboard>{ key, key } },
                        true,
                        true
                    )
                    .get()
            )
            .get('reply_markup');

        Assert.areEqual(true, markup.get('resize_keyboard'));
        Assert.areEqual(true, markup.get('one_time_keyboard'));
        Assert.areEqual(1, ((List<Object>) markup.get('keyboard')).size());
    }

    @IsTest
    static void removeKeyboardAndForceReplyAreSerialized() {
        Map<String, Object> removed = (Map<String, Object>) payloadOf(
                new TelegramMessage.Text('q').removeReplyKeyboard().get()
            )
            .get('reply_markup');
        Assert.areEqual(true, removed.get('remove_keyboard'));

        Map<String, Object> forced = (Map<String, Object>) payloadOf(new TelegramMessage.Text('q').forceReply().get())
            .get('reply_markup');
        Assert.areEqual(true, forced.get('force_reply'));
    }

    @IsTest
    static void emptyKeyboardIsIgnored() {
        Map<String, Object> payload = payloadOf(
            new TelegramMessage.Text('q').addInlineKeyboard(new List<Telegram.InlineKeyboard>()).get()
        );
        Assert.isFalse(payload.containsKey('reply_markup'));
    }

    @IsTest
    static void chatAddressedMessageRequiresAChatId() {
        Test.setMock(HttpCalloutMock.class, new TelegramCalloutMock());
        try {
            new TelegramMessage.Text('hi').get().sendMessage(null, true);
            Assert.fail('sending without a chat id should throw');
        } catch (TelegramException e) {
            Assert.isTrue(e.getMessage().containsIgnoreCase('chat id'));
        }
    }

    @IsTest
    static void answerCallbackQueryIsNotChatAddressed() {
        TelegramCalloutMock mock = new TelegramCalloutMock();
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        new TelegramMessage.AnswerCallbackQuery('cbq-1', 'Saved!', true).get().sendMessage(null, true);
        Test.stopTest();

        Map<String, Object> sent = (Map<String, Object>) JSON.deserializeUntyped(mock.lastRequest.getBody());
        Assert.areEqual('cbq-1', sent.get('callback_query_id'));
        Assert.areEqual(true, sent.get('show_alert'));
        Assert.isFalse(sent.containsKey('chat_id'), 'answerCallbackQuery is not addressed to a chat');
        Assert.isTrue(mock.lastRequest.getEndpoint().endsWith('/answerCallbackQuery'));
    }

    @IsTest
    static void answerInlineQueryIsNotChatAddressed() {
        TelegramCalloutMock mock = new TelegramCalloutMock();
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        new TelegramMessage.AnswerInlineQuery('iq-1', '[]').get().sendMessage(null, true);
        Test.stopTest();

        Assert.isTrue(mock.lastRequest.getEndpoint().endsWith('/answerInlineQuery'));
    }

    @IsTest
    static void editAndDeleteCarryTheMessageIdAsANumber() {
        TelegramCalloutMock mock = new TelegramCalloutMock();
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        new TelegramMessage.EditMessageText('9876543210', 'edited').get().sendMessage(CHAT_ID, true);
        Map<String, Object> edited = (Map<String, Object>) JSON.deserializeUntyped(mock.lastRequest.getBody());

        new TelegramMessage.DeleteMessage('9876543210').get().sendMessage(CHAT_ID, true);
        Test.stopTest();

        Assert.areEqual(9876543210L, edited.get('message_id'), 'Telegram documents message_id as an integer');
        Assert.areEqual(CHAT_ID, edited.get('chat_id'));
        Assert.isTrue(mock.lastRequest.getEndpoint().endsWith('/deleteMessage'));
    }

    @IsTest
    static void rejectsAnInvalidMessageId() {
        try {
            new TelegramMessage.DeleteMessage('not-a-number');
            Assert.fail('a non-numeric message id should throw');
        } catch (TelegramException e) {
            Assert.isTrue(e.getMessage().contains('not-a-number'));
        }
        try {
            new TelegramMessage.EditMessageText('', 'x');
            Assert.fail('a blank message id should throw');
        } catch (TelegramException e) {
            Assert.isTrue(e.getMessage().containsIgnoreCase('required'));
        }
    }

    private static Telegram.InlineKeyboard button(String text) {
        Telegram.InlineKeyboard key = new Telegram.InlineKeyboard();
        key.text = text;
        key.callback_data = text;
        return key;
    }

    private static List<Object> inlineRowsOf(TelegramMessage message) {
        Map<String, Object> markup = (Map<String, Object>) payloadOf(message.get()).get('reply_markup');
        return (List<Object>) markup.get('inline_keyboard');
    }
}
