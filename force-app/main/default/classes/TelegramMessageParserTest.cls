@IsTest
private class TelegramMessageParserTest {
    @IsTest
    static void parsesPrivateTextMessage() {
        TelegramMessageParser parser = new TelegramMessageParser(TelegramTestData.privateText()).parse();

        Assert.isTrue(parser.isMessage(), 'should be a message update');
        Assert.isTrue(parser.isText(), 'should be recognised as text');
        Assert.areEqual('hello bot', parser.getMessage());
        Assert.areEqual(TelegramTestData.BIG_USER_ID, parser.getChatId());
        Assert.areEqual('private', parser.getChatType());
        Assert.areEqual('ada', parser.getSender().username);
        Assert.isFalse(parser.getSender().is_bot);
    }

    /**
     * Regression: ids above 2^31 used to raise
     * "Invalid conversion from runtime type Long to Integer".
     */
    @IsTest
    static void handlesIdsAboveIntegerRange() {
        TelegramMessageParser parser = new TelegramMessageParser(TelegramTestData.privateText()).parse();

        Assert.areEqual(TelegramTestData.BIG_UPDATE_ID, parser.getUpdateId());
        Assert.areEqual('9876543210', parser.getMessageId());
        Assert.areEqual(TelegramTestData.BIG_USER_ID, parser.getSender().id);
    }

    /** Regression: the chat id is not the sender id outside one-to-one chats. */
    @IsTest
    static void groupChatIdDiffersFromSenderId() {
        TelegramMessageParser parser = new TelegramMessageParser(TelegramTestData.groupText()).parse();

        Assert.areEqual(TelegramTestData.GROUP_CHAT_ID, parser.getChatId());
        Assert.areEqual(TelegramTestData.BIG_USER_ID, parser.getSender().id);
        Assert.areNotEqual(parser.getSender().id, parser.getChatId(), 'replying to the sender would DM them');
        Assert.areEqual('supergroup', parser.getChatType());
        Assert.areEqual('Support Team', parser.getChat().title);
    }

    /**
     * Regression: the chained ternaries in buildEntity() overwrote each match
     * with null, so only AUDIO could ever be returned.
     */
    @IsTest
    static void detectsEveryMessageSubType() {
        Assert.isTrue(new TelegramMessageParser(TelegramTestData.photo()).parse().isPhoto(), 'photo');
        Assert.isTrue(new TelegramMessageParser(TelegramTestData.sticker()).parse().isSticker(), 'sticker');
        Assert.isTrue(new TelegramMessageParser(TelegramTestData.voice()).parse().isVoice(), 'voice');
        Assert.isTrue(new TelegramMessageParser(TelegramTestData.audio()).parse().isAudio(), 'audio');
        Assert.isTrue(new TelegramMessageParser(TelegramTestData.document()).parse().isDocument(), 'document');
    }

    @IsTest
    static void photoEntityCarriesThePayload() {
        TelegramMessageParser parser = new TelegramMessageParser(TelegramTestData.photo()).parse();

        Assert.areEqual(Telegram.EntityType.PHOTO, parser.getEntityType());
        Assert.isNotNull(parser.getEntity(), 'entity payload should be exposed');
        Assert.isFalse(parser.isText(), 'a photo is not text');
    }

    /** Telegram sends `document` alongside `animation`; animation must win. */
    @IsTest
    static void animationTakesPrecedenceOverDocument() {
        TelegramMessageParser parser = new TelegramMessageParser(TelegramTestData.animation()).parse();

        Assert.isTrue(parser.isAnimation(), 'animation should win over the document it ships with');
        Assert.isFalse(parser.isDocument());
    }

    @IsTest
    static void unmodelledSubTypeFallsBackToUnknown() {
        TelegramMessageParser parser = new TelegramMessageParser(TelegramTestData.unsupported()).parse();

        Assert.areEqual(Telegram.EntityType.UNKNOWN, parser.getEntityType());
        Assert.isFalse(parser.isText());
    }

    /** Regression: these accessors used to throw a NullPointerException on callbacks. */
    @IsTest
    static void callbackQueryAccessorsAreNullSafe() {
        TelegramMessageParser parser = new TelegramMessageParser(TelegramTestData.callbackQuery()).parse();

        Assert.isTrue(parser.isCallback());
        Assert.areEqual('keyboard1', parser.getMessage());
        Assert.areEqual('4382bfdwdsb323b2d9', parser.getMessageId());
        Assert.areEqual('1234', parser.getCallbackMessageId(), 'needed for editMessageText/deleteMessage');
        Assert.areEqual(TelegramTestData.GROUP_CHAT_ID, parser.getChatId());

        // none of these may throw
        Assert.isNull(parser.getEntity());
        Assert.isNull(parser.getEntityType());
        Assert.isFalse(parser.isText());
        Assert.isFalse(parser.isPhoto());
        Assert.isFalse(parser.isSticker());
        Assert.isFalse(parser.isVoice());
        Assert.isFalse(parser.isAudio());
        Assert.isFalse(parser.isVideo());
        Assert.isFalse(parser.isVideoNote());
        Assert.isFalse(parser.isLocation());
        Assert.isFalse(parser.isContact());
    }

    @IsTest
    static void inlineQueryFallsBackToTheSenderAsChat() {
        TelegramMessageParser parser = new TelegramMessageParser(TelegramTestData.inlineQuery()).parse();

        Assert.isTrue(parser.isInline());
        Assert.areEqual('order status', parser.getMessage());
        Assert.areEqual(TelegramTestData.BIG_USER_ID, parser.getChatId(), 'inline queries carry no chat');
        Assert.areEqual('sender', parser.getChatType());
        Assert.isFalse(parser.isText(), 'must not throw');
    }

    /** Previously parsed to an all-null result. */
    @IsTest
    static void parsesChannelPost() {
        TelegramMessageParser parser = new TelegramMessageParser(TelegramTestData.channelPost()).parse();

        Assert.isTrue(parser.isMessage());
        Assert.isTrue(parser.isText());
        Assert.areEqual('broadcast', parser.getMessage());
        Assert.areEqual(TelegramTestData.GROUP_CHAT_ID, parser.getChatId());
        Assert.areEqual('channel', parser.getChatType());
    }
}
