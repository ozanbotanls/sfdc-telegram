@IsTest
public class TelegramCalloutMock implements HttpCalloutMock {
    public Integer statusCode;
    public String body;
    public HttpRequest lastRequest;
    public Integer callCount = 0;

    public TelegramCalloutMock() {
        this(200, '{"ok":true,"result":{"message_id":42}}');
    }

    public TelegramCalloutMock(Integer statusCode, String body) {
        this.statusCode = statusCode;
        this.body = body;
    }

    public HttpResponse respond(HttpRequest req) {
        this.lastRequest = req;
        this.callCount++;
        HttpResponse res = new HttpResponse();
        res.setStatusCode(this.statusCode);
        res.setBody(this.body);
        res.setHeader('Content-Type', 'application/json');
        return res;
    }
}
