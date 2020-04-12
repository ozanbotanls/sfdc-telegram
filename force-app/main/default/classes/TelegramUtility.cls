public with sharing class TelegramUtility {
    public static final String TELEGRAM_CHAT_TOKEN = '<your bot token here>';
    public static String sendMessage(String data, String method, Boolean isImmediate) {
        if (isImmediate) {
            return sendImmediate(data, method);
        } else {
            sendFuture(data, method);
            return null;
        }
    }
    private static String sendMessageHandler(String data, String method) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://api.telegram.org/bot' + TELEGRAM_CHAT_TOKEN + '/' + method);
        req.setMethod('POST');
        req.setHeader('content-type', 'application/json');
        req.setBody(data);
        Http http = new Http();
        HttpResponse res = http.send(req);
        return res.getBody();
    }
    private static String sendImmediate(String data, String method) {
        return sendMessageHandler(data, method);
    }
    @future(callout=true)
    private static void sendFuture(String data, String method) {
        sendMessageHandler(data, method);
    }
}