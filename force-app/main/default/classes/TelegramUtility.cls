public with sharing class TelegramUtility {
    /**
     * Named Credential holding the bot token in its URL
     * (https://api.telegram.org/bot<TOKEN>). Keeping the token there rather
     * than in a queryable field means it never reaches Apex, SOQL, debug logs
     * or the browser.
     */
    public static final String NAMED_CREDENTIAL = 'callout:Telegram_Bot_API';
    /** Telegram is normally fast; fail loudly rather than tying up the transaction. */
    @TestVisible
    private static final Integer TIMEOUT_MS = 20000;
    /** Upper bound on 429 re-enqueues before the job is allowed to fail. */
    public static final Integer MAX_RETRIES = 3;

    /**
     * @param data   serialized Telegram payload
     * @param method Bot API method, e.g. `sendMessage`
     * @param isImmediate true to call out synchronously and return the response
     *                    body; false to hand the callout to a Queueable.
     * @return the response body when synchronous, otherwise null.
     */
    public static String sendMessage(String data, String method, Boolean isImmediate) {
        if (isImmediate == true) {
            return send(data, method);
        }
        System.enqueueJob(new TelegramCalloutQueueable(data, method));
        return null;
    }

    /**
     * Synchronous callout. Throws TelegramException on any non-2xx response
     * rather than handing the caller an error body that is indistinguishable
     * from success.
     */
    public static String send(String data, String method) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(NAMED_CREDENTIAL + '/' + method);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(TIMEOUT_MS);
        req.setBody(data);

        HttpResponse res = new Http().send(req);
        Integer status = res.getStatusCode();
        if (status >= 200 && status < 300) {
            return res.getBody();
        }
        throw buildException(method, status, res.getBody());
    }

    /** Unpacks Telegram's error envelope so callers can branch on error_code/retry_after. */
    @TestVisible
    private static TelegramException buildException(String method, Integer status, String body) {
        Integer errorCode;
        String description;
        Integer retryAfter;
        try {
            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(body);
            if (parsed.get('error_code') != null) {
                errorCode = Integer.valueOf(String.valueOf(parsed.get('error_code')));
            }
            description = (String) parsed.get('description');
            Map<String, Object> parameters = (Map<String, Object>) parsed.get('parameters');
            if (parameters != null && parameters.get('retry_after') != null) {
                retryAfter = Integer.valueOf(String.valueOf(parameters.get('retry_after')));
            }
        } catch (Exception parseFailure) {
            // a non-JSON body (gateway error page, truncated response) is still a failure
            description = body;
        }
        TelegramException e = new TelegramException(
            'Telegram ' + method + ' failed with HTTP ' + status + (description == null ? '' : ': ' + description)
        );
        e.method = method;
        e.statusCode = status;
        e.errorCode = errorCode;
        e.description = description;
        e.retryAfter = retryAfter;
        return e;
    }
}
