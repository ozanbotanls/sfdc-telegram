@IsTest
private class TelegramWebhookTest {
    private static final String SECRET = 'c0ffee0123456789c0ffee0123456789';

    /** Named in Handler_Class__c by the tests below. */
    public class StubHandler implements TelegramWebhookHandler {
        public void handleUpdate(TelegramMessageParser telegramUpdate) {
            lastChatId = telegramUpdate.getChatId();
            invocations++;
        }
    }

    public class ExplodingHandler implements TelegramWebhookHandler {
        public void handleUpdate(TelegramMessageParser telegramUpdate) {
            throw new TelegramException('handler blew up');
        }
    }

    private static String lastChatId;
    private static Integer invocations = 0;

    private static void givenSetup(String handlerClass) {
        TelegramWebhook.setupOverridden = true;
        TelegramWebhook.setupOverride = new Telegram_Setup__mdt(
            Is_Active__c = true,
            Webhook_Secret__c = SECRET,
            Handler_Class__c = handlerClass
        );
    }

    private static RestResponse post(String payload, String secretHeader) {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/telegram/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(payload);
        if (secretHeader != null) {
            req.addHeader('X-Telegram-Bot-Api-Secret-Token', secretHeader);
        }
        RestContext.request = req;
        RestContext.response = new RestResponse();

        TelegramWebhook.receiveUpdate();
        return RestContext.response;
    }

    @IsTest
    static void dispatchesToTheConfiguredHandlerWithTheRightSecret() {
        givenSetup('TelegramWebhookTest.StubHandler');
        invocations = 0;

        RestResponse res = post(TelegramTestData.groupText(), SECRET);

        Assert.areEqual(200, res.statusCode);
        Assert.areEqual(1, invocations, 'the handler should have been called');
        Assert.areEqual(TelegramTestData.GROUP_CHAT_ID, lastChatId, 'the handler gets the chat id, not the sender id');
    }

    @IsTest
    static void rejectsAWrongSecret() {
        givenSetup('TelegramWebhookTest.StubHandler');
        invocations = 0;

        RestResponse res = post(TelegramTestData.privateText(), 'not-the-secret');

        Assert.areEqual(401, res.statusCode);
        Assert.areEqual(0, invocations, 'a forged update must never reach the handler');
    }

    @IsTest
    static void rejectsAMissingSecretHeader() {
        givenSetup('TelegramWebhookTest.StubHandler');
        invocations = 0;

        RestResponse res = post(TelegramTestData.privateText(), null);

        Assert.areEqual(401, res.statusCode);
        Assert.areEqual(0, invocations);
    }

    /** A value that merely shares a prefix must not pass. */
    @IsTest
    static void rejectsAPrefixOfTheSecret() {
        givenSetup('TelegramWebhookTest.StubHandler');

        Assert.areEqual(401, post(TelegramTestData.privateText(), SECRET.substring(0, 10)).statusCode);
        Assert.areEqual(401, post(TelegramTestData.privateText(), SECRET + 'x').statusCode);
    }

    @IsTest
    static void headerLookupIsCaseInsensitive() {
        givenSetup('TelegramWebhookTest.StubHandler');
        invocations = 0;

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/telegram/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(TelegramTestData.privateText());
        req.addHeader('x-telegram-bot-api-secret-token', SECRET);
        RestContext.request = req;
        RestContext.response = new RestResponse();

        TelegramWebhook.receiveUpdate();

        Assert.areEqual(200, RestContext.response.statusCode);
        Assert.areEqual(1, invocations);
    }

    /** Without an active setup record there is nothing to authenticate against. */
    @IsTest
    static void failsClosedWithoutAnActiveSetupRecord() {
        TelegramWebhook.setupOverridden = true;
        TelegramWebhook.setupOverride = new Telegram_Setup__mdt(Is_Active__c = false, Webhook_Secret__c = SECRET);

        RestResponse res = post(TelegramTestData.privateText(), SECRET);

        Assert.areEqual(503, res.statusCode, 'an inactive record is no record at all');
    }

    @IsTest
    static void failsClosedWithNoSetupRecordAtAll() {
        TelegramWebhook.setupOverridden = true;
        TelegramWebhook.setupOverride = null;

        RestResponse res = post(TelegramTestData.privateText(), SECRET);

        Assert.areEqual(503, res.statusCode);
    }

    @IsTest
    static void blankSecretNeverAuthenticates() {
        givenSetup('TelegramWebhookTest.StubHandler');
        TelegramWebhook.setupOverride.Webhook_Secret__c = null;

        Assert.areEqual(401, post(TelegramTestData.privateText(), '').statusCode);
    }

    @IsTest
    static void unconfiguredHandlerStillAcknowledges() {
        givenSetup(null);

        RestResponse res = post(TelegramTestData.privateText(), SECRET);

        Assert.areEqual(200, res.statusCode, 'nothing to dispatch to, but the delivery was valid');
    }

    @IsTest
    static void handlerFailureReturns500SoTelegramRedelivers() {
        givenSetup('TelegramWebhookTest.ExplodingHandler');

        RestResponse res = post(TelegramTestData.privateText(), SECRET);

        Assert.areEqual(500, res.statusCode);
    }

    @IsTest
    static void unknownHandlerClassIsReportedAsAFailure() {
        givenSetup('NoSuchHandlerClass');

        RestResponse res = post(TelegramTestData.privateText(), SECRET);

        Assert.areEqual(500, res.statusCode);
    }

    @IsTest
    static void classThatDoesNotImplementTheInterfaceIsRejected() {
        givenSetup('TelegramCalloutMock');

        RestResponse res = post(TelegramTestData.privateText(), SECRET);

        Assert.areEqual(500, res.statusCode);
    }
}
