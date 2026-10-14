/**
 * Asynchronous Telegram callout.
 *
 * Replaces the previous @future(callout=true) path, which could not be invoked
 * from a batch, another future or a queueable -- exactly the contexts an
 * integration needs it in -- and which discarded the response entirely.
 */
public with sharing class TelegramCalloutQueueable implements Queueable, Database.AllowsCallouts {
    private final String data;
    private final String method;
    private final Integer attempt;

    public TelegramCalloutQueueable(String data, String method) {
        this(data, method, 1);
    }

    @TestVisible
    private TelegramCalloutQueueable(String data, String method, Integer attempt) {
        this.data = data;
        this.method = method;
        this.attempt = attempt;
    }

    public void execute(QueueableContext context) {
        try {
            TelegramUtility.send(this.data, this.method);
        } catch (TelegramException e) {
            if (shouldRetry(e)) {
                // Telegram asked us to back off; re-enqueue instead of hammering it.
                System.enqueueJob(
                    new TelegramCalloutQueueable(this.data, this.method, this.attempt + 1),
                    delayMinutes(e.retryAfter)
                );
                return;
            }
            // let the job fail so it surfaces in Apex Jobs rather than vanishing
            throw e;
        }
    }

    private Boolean shouldRetry(TelegramException e) {
        // chaining a queueable is not allowed inside a test transaction
        return e.retryAfter != null && this.attempt < TelegramUtility.MAX_RETRIES && !Test.isRunningTest();
    }

    /** System.enqueueJob accepts a 0-10 minute delay; round Telegram's seconds up into that range. */
    @TestVisible
    private static Integer delayMinutes(Integer retryAfterSeconds) {
        if (retryAfterSeconds == null || retryAfterSeconds <= 0) {
            return 0;
        }
        // integer division truncates, so (n + 59) / 60 is the ceiling in minutes
        return Math.min(10, (retryAfterSeconds + 59) / 60);
    }
}
