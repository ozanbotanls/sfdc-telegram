/**
 * Raised when the Telegram Bot API rejects a request. Apex supplies the
 * constructors for exception classes, so the Telegram-specific detail is
 * populated by TelegramUtility after construction.
 */
public class TelegramException extends Exception {
    /** HTTP status returned by api.telegram.org. */
    public Integer statusCode;
    /** Telegram's own `error_code` from the response body, when present. */
    public Integer errorCode;
    /** Telegram's own `description` from the response body, when present. */
    public String description;
    /** Seconds to wait before retrying, from `parameters.retry_after` on a 429. */
    public Integer retryAfter;
    /** The Bot API method that failed, e.g. `sendMessage`. */
    public String method;
}
