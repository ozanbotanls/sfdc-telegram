/**
 * Public endpoint Telegram posts updates to.
 *
 * Authentication is the `X-Telegram-Bot-Api-Secret-Token` header, which Telegram
 * echoes on every delivery after `setWebhook` is called with `secret_token`.
 * The previous (README-only) scheme put the bot token in the URL path, where it
 * landed in site access logs, Event Monitoring and browser history -- and the
 * token is full control of the bot, whereas this secret only permits forging
 * updates.
 */
@RestResource(urlMapping='/telegram/*')
global with sharing class TelegramWebhook {
    @TestVisible
    private static final String SECRET_HEADER = 'X-Telegram-Bot-Api-Secret-Token';

    @HttpPost
    global static void receiveUpdate() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        if (res == null) {
            res = new RestResponse();
            RestContext.response = res;
        }

        Telegram_Setup__mdt setup = getActiveSetup();
        if (setup == null) {
            res.statusCode = 503;
            res.responseBody = Blob.valueOf('{"error":"No active Telegram Setup record."}');
            return;
        }
        if (!secureEquals(setup.Webhook_Secret__c, getHeader(req, SECRET_HEADER))) {
            // do not disclose which half was wrong
            res.statusCode = 401;
            res.responseBody = Blob.valueOf('{"error":"Unauthorized."}');
            return;
        }

        try {
            TelegramMessageParser update = new TelegramMessageParser(req.requestBody.toString()).parse();
            TelegramWebhookHandler handler = resolveHandler(setup.Handler_Class__c);
            if (handler != null) {
                handler.handleUpdate(update);
            } else {
                System.debug(
                    LoggingLevel.WARN,
                    'No TelegramWebhookHandler configured; dropping update ' + update.getUpdateId()
                );
            }
            res.statusCode = 200;
        } catch (Exception e) {
            // a non-2xx makes Telegram redeliver, which is what we want for a transient failure
            System.debug(LoggingLevel.ERROR, 'Telegram webhook failed: ' + e.getMessage() + '\n' + e.getStackTraceString());
            res.statusCode = 500;
            res.responseBody = Blob.valueOf('{"error":"Handler failed."}');
        }
    }

    @TestVisible
    private static Telegram_Setup__mdt getActiveSetup() {
        // getAll() does not consume a SOQL query
        for (Telegram_Setup__mdt setup : Telegram_Setup__mdt.getAll().values()) {
            if (setup.Is_Active__c == true) {
                return setup;
            }
        }
        return null;
    }

    /** HTTP header names are case-insensitive; the RestRequest map is not. */
    @TestVisible
    private static String getHeader(RestRequest req, String name) {
        if (req == null || req.headers == null) {
            return null;
        }
        for (String key : req.headers.keySet()) {
            if (key.equalsIgnoreCase(name)) {
                return req.headers.get(key);
            }
        }
        return null;
    }

    /**
     * Compares SHA-256 digests so the time taken does not depend on how many
     * leading characters match, nor on the length of the supplied value.
     */
    @TestVisible
    private static Boolean secureEquals(String expected, String provided) {
        if (String.isBlank(expected) || provided == null) {
            return false;
        }
        String a = EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf(expected)));
        String b = EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf(provided)));
        Integer difference = 0;
        for (Integer i = 0; i < a.length(); i++) {
            difference |= a.charAt(i) ^ b.charAt(i);
        }
        return difference == 0;
    }

    @TestVisible
    private static TelegramWebhookHandler resolveHandler(String className) {
        if (String.isBlank(className)) {
            return null;
        }
        Type handlerType = Type.forName(className);
        if (handlerType == null) {
            throw new TelegramException('Configured handler class "' + className + '" was not found.');
        }
        Object instance = handlerType.newInstance();
        if (!(instance instanceof TelegramWebhookHandler)) {
            throw new TelegramException('"' + className + '" does not implement TelegramWebhookHandler.');
        }
        return (TelegramWebhookHandler) instance;
    }
}
