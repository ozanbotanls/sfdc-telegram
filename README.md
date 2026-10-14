# _Telegram Connector for Salesforce_

---

[Bot API]: https://core.telegram.org/bots/api

This codebase will allow Salesforce Developers to easily integrate the Salesforce platform with Telegram through [Bot API]. This is not complete coverage, but fair enough to get developers going by eliminating a lot of hassles with which, under normal circumstances, they might have been facing in overcoming basic communication between two systems.

## Install using Salesforce DX

The retired `sfdx force:*` commands have been replaced by the `sf` CLI.

1.  Authenticate with your dev hub org:

    ```zsh
    sf org login web --set-default-dev-hub --alias devhuborg
    ```

1.  Clone the repository:

    ```zsh
    git clone https://github.com/ozanbotanls/sfdc-telegram.git
    cd sfdc-telegram
    ```

1.  Create a scratch org and provide it with an alias:

    ```zsh
    sf org create scratch --definition-file config/project-scratch-def.json --alias telegram --set-default
    ```

1.  Deploy the app to your scratch org:

    ```zsh
    sf project deploy start --target-org telegram
    ```

1.  Assign the Telegram permission set to the default user:

    ```zsh
    sf org assign permset --name Telegram --target-org telegram
    ```

1.  Open the scratch org:

    ```zsh
    sf org open --target-org telegram
    ```

### Running the tests

```zsh
npm ci
npm run lint              # eslint over the Lightning Web Components
npm run prettier:verify   # also parses every Apex file, so it catches syntax errors
npm run test:unit         # LWC Jest tests
sf apex run test --target-org telegram --code-coverage --result-format human
```

Static analysis of the Apex needs no org:

```zsh
sf plugins install code-analyzer
sf code-analyzer run --rule-selector pmd:apex --workspace force-app
```

## Setting Up Your Bot Token

The token BotFather gives you is **full control of your bot**. It is stored in the
`Telegram_Bot_API` **Named Credential** that ships with this project, not in a custom field:

> **Setup > Named Credentials > Telegram Bot API > Edit**, and set the URL to
> `https://api.telegram.org/bot<YOUR_BOT_TOKEN>`

Apex then calls out via `callout:Telegram_Bot_API/sendMessage`, so the token never appears in Apex,
in a SOQL result, in a debug log, or in the browser.

> :information_source: The token is still readable by anyone who can open Setup in your org. A Named
> Credential narrows the audience from "everyone with the Telegram permission set" to "administrators",
> and keeps it out of logs -- it does not hide it from an admin.

Then create a **Telegram Setup** custom metadata record (**Setup > Custom Metadata Types > Telegram
Setup > Manage Records**), tick **Is Active**, and set **Handler Class** to the API name of your
`TelegramWebhookHandler` implementation. **Webhook Secret** is filled in for you when you register
the webhook.

## Registration for Telegram Webhook Service

[Update]: https://core.telegram.org/bots/api#update

In order to constantly _listen_ to incoming messages that you will receive in your chat group and to get them momentarily from within your server, Telegram [Bot API] provides you with a _webhook service_ that pings your endpoint whenever an [Update] occurs in the specified chat group. To ease the setup process, this _Connector_ has a custom LWC for you to set a webhook.

![alt text](https://github.com/ozanbotanls/sfdc-telegram/blob/master/readmephoto/telegram_setup.png "Telegram Setup")

[Apex REST]: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_rest_code_sample_basic.htm
[Public Site]: https://help.salesforce.com/articleView?id=sites_setup_overview.htm&type=5

Because Telegram will only pass a payload without going through 'authorization' flow, the best way to expose an endpoint convenient to this purpose on the Salesforce side is to create a [Public Site] that maps to an [Apex REST] implementation handling incoming updates.

This _Connector_ ships that implementation: **`TelegramWebhook`**, mapped to `/telegram/*`. Create a
public site, assign the **`Telegram_Webhook_Guest`** permission set to its guest user (a
least-privilege set -- do **not** give the guest user the admin `Telegram` permission set), then pick
the site in the setup component and press "Register".

### How incoming requests are authenticated

Registration generates a random **webhook secret**, stores it on the Telegram Setup record and passes
it to Telegram as `setWebhook`'s `secret_token`. Telegram then echoes it in the
`X-Telegram-Bot-Api-Secret-Token` header of every delivery, and `TelegramWebhook` rejects anything
that does not match with a **401**, using a constant-time comparison.

> :warning: Earlier versions of this README suggested appending the **bot token** to the public
> webhook URL and comparing it in your own REST class. Do not do that. A URL path is recorded in site
> access logs, Event Monitoring and browser history, and the bot token is the credential for your
> entire bot. A leaked webhook secret only lets someone post forged updates; a leaked bot token lets
> them read and send everything. (That snippet also referenced
> `TelegramUtility.TELEGRAM_CHAT_TOKEN`, which never existed in this codebase.)

### Handling updates

Implement `TelegramWebhookHandler` and name your class in the **Handler Class** field of the Telegram
Setup record. `TelegramWebhook` authenticates the delivery, parses it, and hands you the result.

```apex
public with sharing class MyTelegramHandler implements TelegramWebhookHandler {
    public void handleUpdate(TelegramMessageParser telegramUpdate) {
        // always reply to the chat, not to the sender -- they differ in groups and channels
        String chatId = telegramUpdate.getChatId();

        if (telegramUpdate.isCallback()) {
            new TelegramMessage.AnswerCallbackQuery(telegramUpdate.getMessageId(), 'Got it!')
                .get()
                .sendMessage(null, false);
            return;
        }
        if (telegramUpdate.isText()) {
            new TelegramMessage.Text('You said: ' + telegramUpdate.getMessage()).get().sendMessage(chatId, false);
        }
    }
}
```

## Building and Sending Messages with _Connector_

```apex
// send a basic text message synchronously (pass false as a second param for async)
new TelegramMessage.Text('<chat message>').get().sendMessage(chatId, true);
```

The second parameter picks the transport. `true` calls out synchronously and returns Telegram's
response body. `false` hands the callout to `TelegramCalloutQueueable`, which can be enqueued from a
trigger, a batch, another queueable or a future -- unlike the `@future` it replaces -- and which
backs off and re-enqueues when Telegram answers HTTP 429.

Any non-2xx response raises a **`TelegramException`** carrying Telegram's own `error_code`,
`description` and `retry_after`, so a failed send can no longer be mistaken for a successful one.

```apex
try {
    new TelegramMessage.Text('hello').get().sendMessage(chatId, true);
} catch (TelegramException e) {
    System.debug(e.statusCode + ' / ' + e.errorCode + ' / ' + e.description);
}
```

[InlineKeyboardMarkup]: https://core.telegram.org/bots/api#inlinekeyboardmarkup
[ReplyKeyboardMarkup]: https://core.telegram.org/bots/api#replykeyboardmarkup

Telegram has [InlineKeyboardMarkup] and [ReplyKeyboardMarkup], two distinct keyboard entities that you can utilize in order to provide button interaction with the user in the chat. This becomes an even more desired option in case you have a questionnaire or flow-based conversation to get inputs from the users. Build them in Apex easily as shown below.

```apex
// send a text message with InlineKeyboard entities for user to response (useful for quiz, etc.)
Telegram.InlineKeyboard inlineKeyboard1 = new Telegram.InlineKeyboard();
inlineKeyboard1.text = 'My answer is keyboard1';
inlineKeyboard1.callback_data = 'keyboard1';
Telegram.InlineKeyboard inlineKeyboard2 = new Telegram.InlineKeyboard();
inlineKeyboard2.text = 'My answer is keyboard2';
inlineKeyboard2.callback_data = 'keyboard2';
new TelegramMessage.Text('<chat message>')
    .addInlineKeyboard(new List<Telegram.InlineKeyboard>{ inlineKeyboard1, inlineKeyboard2 })
    .get()
    .sendMessage(chatId, true);

// send a text message with ReplyKeyboard entities for user to react/navigate (flow-based interactions, etc.)
Telegram.ReplyKeyboard replyKeyboard1 = new Telegram.ReplyKeyboard();
replyKeyboard1.text = 'Open a Case';
Telegram.ReplyKeyboard replyKeyboard2 = new Telegram.ReplyKeyboard();
replyKeyboard2.text = 'Get My Order Status';
new TelegramMessage.Text('Choose a Salesforce action')
    .addReplyKeyboard(new List<Telegram.ReplyKeyboard>{ replyKeyboard1, replyKeyboard2 }, true, true)
    .get()
    .sendMessage(chatId, true);
```

Passing a flat list stacks each button in its own row. To put buttons **side by side**, pass one inner
list per row:

```apex
new TelegramMessage.Text('Pick one')
    .addInlineKeyboard(
        new List<List<Telegram.InlineKeyboard>>{
            new List<Telegram.InlineKeyboard>{ inlineKeyboard1, inlineKeyboard2 }, // one row, two buttons
            new List<Telegram.InlineKeyboard>{ inlineKeyboard3 }                   // second row
        }
    )
    .get()
    .sendMessage(chatId, true);
```

Whenever the user taps an inline button, Telegram sends a `callback_query` that **must** be answered --
until it is, the button keeps spinning for the user.

```apex
// acknowledge the tap (optionally as a pop-up alert with the third parameter)
new TelegramMessage.AnswerCallbackQuery(parser.getMessageId(), 'Saved!').get().sendMessage(null, true);

// ...and edit or remove the message the keyboard was attached to
new TelegramMessage.EditMessageText(parser.getCallbackMessageId(), 'You picked keyboard1')
    .get()
    .sendMessage(parser.getChatId(), true);
new TelegramMessage.DeleteMessage(parser.getCallbackMessageId()).get().sendMessage(parser.getChatId(), true);

// respond to an inline_query with a serialized InlineQueryResult array
new TelegramMessage.AnswerInlineQuery(parser.getMessageId(), JSON.serialize(results))
    .get()
    .sendMessage(null, true);
```

---

Sometimes you might need to force the user to reply to one of your specific messages. So, take this!

```apex
// force user to reply specifically to what your bot is sending out in the chat.
new TelegramMessage.Text('Your response will be linked to this')
    .forceReply()
    .get()
    .sendMessage(chatId, true);
```

---

Other than text messages, there are a couple of more options to be used with the _Connector_

```apex
// send a Photo
new TelegramMessage.Photo('photoUrlOrFileId', 'photoCaption').get().sendMessage(chatId, true);

// send a Sticker
new TelegramMessage.Sticker('stickerUrlOrFileId').get().sendMessage(chatId, true);

// send a Location
new TelegramMessage.Location(12.45654, 20.53214).get().sendMessage(chatId, true);

// send a Contact info
new TelegramMessage.Contact('phoneNumber', 'fName', 'lName').get().sendMessage(chatId, true);
```

---

One cool thing with the **ChatAction** class is that it gives your bot the ability to act more "_humanly_" by sending action status before the actual message is sent off. An unsupported action now raises a `TelegramException` instead of silently sending an empty payload.

```apex
// options are: 'typing','upload_photo','record_video','upload_video','record_audio','upload_audio',
// 'upload_document','find_location','record_video_note','upload_video_note','choose_sticker'
new TelegramMessage.ChatAction('typing').get().sendMessage(chatId, true);
```

## Parsing Telegram Updates with _Connector_

You can leverage **TelegramMessageParser** class in order to parse the payload coming from Telegram webhook service.
Basically, pass that payload through the constructor and call **_parse()_** method to wrap up the things in a single entity.

```apex
String webhookPayload; // sent off by Telegram
TelegramMessageParser parser = new TelegramMessageParser(webhookPayload).parse();
```

Your **_parser_** instance now holds all the things with which you will need to handle your bot's user interactions.

> :warning: **Always reply to `getChatId()`, never to `getSender().id`.** They are the same value only in
> one-to-one chats. In a group, supergroup or channel the chat id is a different (and usually negative)
> number, so a reply addressed to the sender id is delivered as a DM or rejected outright.

```apex
// where to send the reply
String chatId = parser.getChatId();
String chatType = parser.getChatType(); // private | group | supergroup | channel

// who wrote to the bot
Telegram.TelegramUser sender = parser.getSender();
String fName = sender.first_name;
String lName = sender.last_name;
String username = sender.username;
Boolean isBotUser = sender.is_bot;
```

Moreover, you will have the chance to identify which type of incoming message your bot will be coping with.
This is especially crucial and handy when it comes to conducting quiz or flow-based user interactions.
All of the `is*()` checks below are null-safe -- they return `false` rather than throwing when the update
carries no entity of that kind.

```apex
// DETERMINE THE TYPE OF MESSAGE
if (parser.isCallback()) {
    // incoming response is stemmed from CallbackQuery.
    String callbackAction = parser.getMessage();
    // acknowledge it, otherwise the button spins until Telegram times it out
    new TelegramMessage.AnswerCallbackQuery(parser.getMessageId(), 'Got it!').get().sendMessage(null, true);
}

if (parser.isInline()) {
    // incoming response is stemmed from InlineQuery.
    String inlineQuery = parser.getMessage();
}

if (parser.isText()) {
    // incoming message is text
    String text = parser.getMessage();
}

if (parser.isPhoto()) {
    Object photo = parser.getEntity();
}

// also available: isAudio(), isVoice(), isSticker(), isDocument(), isVideo(),
// isVideoNote(), isAnimation(), isLocation(), isContact()
```

If you would rather switch than chain, `getEntityType()` returns the `Telegram.EntityType` enum value
directly (`UNKNOWN` for a message sub-type the connector does not model).

```apex
switch on parser.getEntityType() {
    when TEXT { /* ... */ }
    when PHOTO { /* ... */ }
    when else { /* ... */ }
}
```
