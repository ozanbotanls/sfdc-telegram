@IsTest
private class TelegramUtilityTest {
    private static final String PAYLOAD = '{"chat_id":"1","text":"hi"}';

    @IsTest
    static void returnsBodyOnSuccess() {
        TelegramCalloutMock mock = new TelegramCalloutMock();
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        String body = TelegramUtility.sendMessage(PAYLOAD, 'sendMessage', true);
        Test.stopTest();

        Assert.areEqual('{"ok":true,"result":{"message_id":42}}', body);
        Assert.areEqual('POST', mock.lastRequest.getMethod());
        Assert.areEqual(
            TelegramUtility.NAMED_CREDENTIAL + '/sendMessage',
            mock.lastRequest.getEndpoint(),
            'the bot token must come from the Named Credential, not the code'
        );
        Assert.areEqual('application/json', mock.lastRequest.getHeader('Content-Type'));
    }

    /** Regression: a 400 used to be returned as a body, indistinguishable from success. */
    @IsTest
    static void throwsTypedExceptionOnBadRequest() {
        Test.setMock(
            HttpCalloutMock.class,
            new TelegramCalloutMock(400, '{"ok":false,"error_code":400,"description":"Bad Request: chat not found"}')
        );

        Test.startTest();
        try {
            TelegramUtility.send(PAYLOAD, 'sendMessage');
            Assert.fail('a 400 response should raise TelegramException');
        } catch (TelegramException e) {
            Assert.areEqual(400, e.statusCode);
            Assert.areEqual(400, e.errorCode);
            Assert.areEqual('Bad Request: chat not found', e.description);
            Assert.areEqual('sendMessage', e.method);
            Assert.isTrue(e.getMessage().contains('chat not found'), 'message should carry Telegram\'s description');
        }
        Test.stopTest();
    }

    @IsTest
    static void exposesRetryAfterOnRateLimit() {
        Test.setMock(
            HttpCalloutMock.class,
            new TelegramCalloutMock(
                429,
                '{"ok":false,"error_code":429,"description":"Too Many Requests","parameters":{"retry_after":45}}'
            )
        );

        Test.startTest();
        try {
            TelegramUtility.send(PAYLOAD, 'sendMessage');
            Assert.fail('a 429 response should raise TelegramException');
        } catch (TelegramException e) {
            Assert.areEqual(429, e.statusCode);
            Assert.areEqual(45, e.retryAfter);
        }
        Test.stopTest();
    }

    @IsTest
    static void handlesNonJsonErrorBody() {
        Test.setMock(HttpCalloutMock.class, new TelegramCalloutMock(502, '<html>Bad Gateway</html>'));

        Test.startTest();
        try {
            TelegramUtility.send(PAYLOAD, 'sendMessage');
            Assert.fail('a 502 response should raise TelegramException');
        } catch (TelegramException e) {
            Assert.areEqual(502, e.statusCode);
            Assert.isNull(e.errorCode);
            Assert.areEqual('<html>Bad Gateway</html>', e.description);
        }
        Test.stopTest();
    }

    @IsTest
    static void asyncPathEnqueuesAQueueable() {
        TelegramCalloutMock mock = new TelegramCalloutMock();
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        String body = TelegramUtility.sendMessage(PAYLOAD, 'sendMessage', false);
        Assert.isNull(body, 'the async path returns nothing');
        Test.stopTest(); // the queueable runs here

        Assert.areEqual(1, mock.callCount, 'the queued callout should have run');
    }

    @IsTest
    static void queueableSurfacesFailuresInsteadOfSwallowingThem() {
        Test.setMock(
            HttpCalloutMock.class,
            new TelegramCalloutMock(400, '{"ok":false,"error_code":400,"description":"Bad Request"}')
        );

        Test.startTest();
        try {
            // run it directly: an uncaught failure inside Test.stopTest() cannot be asserted on
            new TelegramCalloutQueueable(PAYLOAD, 'sendMessage').execute(null);
            Assert.fail('the queueable should rethrow so the job fails visibly');
        } catch (TelegramException e) {
            Assert.areEqual(400, e.statusCode);
        }
        Test.stopTest();
    }

    @IsTest
    static void retryDelayIsRoundedUpIntoTheAllowedRange() {
        Assert.areEqual(0, TelegramCalloutQueueable.delayMinutes(null));
        Assert.areEqual(0, TelegramCalloutQueueable.delayMinutes(0));
        Assert.areEqual(1, TelegramCalloutQueueable.delayMinutes(1));
        Assert.areEqual(1, TelegramCalloutQueueable.delayMinutes(60));
        Assert.areEqual(2, TelegramCalloutQueueable.delayMinutes(61));
        Assert.areEqual(10, TelegramCalloutQueueable.delayMinutes(99999), 'enqueueJob caps the delay at 10 minutes');
    }
}
