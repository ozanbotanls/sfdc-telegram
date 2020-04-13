# _Telegram Connector for Salesforce_
---------
[Bot API]: https://core.telegram.org/bots/api
This codebase will allow Salesforce Developers to easily integrate the Salesforce platform with Telegram through [Bot API]. This is not complete coverage, but fair enough to get developers going by eliminating a lot of hassles with which, under normal circumstances, they might have been facing in overcoming basic communication between two systems.

## Install using Salesforce DX

1.  Authenticate with your dev hub org:

    ```zsh
    sfdx force:auth:web:login -d -a devhuborg
    ```

1.  Clone the repository:

    ```zsh
    git clone https://github.com/ozanbotanls/sfdc-telegram.git
    cd sfdc-telegram
    ```

1.  Create a scratch org and provide it with an alias:

    ```zsh
    sfdx force:org:create -s -f config/project-scratch-def.json -a telegram
    ```

1.  Push the app to your scratch org:

    ```zsh
    sfdx force:source:push
    ```

1.  Assign the Telegram permission set to the default user:

    ```zsh
    sfdx force:user:permset:assign -n Telegram
    ```

1.  Open the scratch org:

    ```
    sfdx force:org:open
    ```

## Registration for Telegram Webhook Service
[Update]: https://core.telegram.org/bots/api#update
In order to constantly _listen_ to incoming messages that you will receive in your chat group and to get them momentarily from within your server, Telegram [Bot API] provides you with a _webhook service_ that pings your endpoint whenever an [Update] occurs in the specified chat group. To ease the setup process, this _Connector_ has a custom LWC for you to set a webhook.

![alt text](https://github.com/ozanbotanls/sfdc-telegram/blob/master/readmephoto/telegram_setup.png "Telegram Setup")

[Apex REST]: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_rest_code_sample_basic.htm
[Public Site]: https://help.salesforce.com/articleView?id=sites_setup_overview.htm&type=5
Because Telegram will only pass a payload without going through 'authorization' flow, the best way to expose an endpoint convenient to this purpose on the Salesforce side is to create a [Public Site] that maps to an [Apex REST] implementation handling incoming updates.

Create a public site, grant it access base Telegram classes as well as the custom Apex Rest resource that you will create. In the setup page above, after creating the site and the Apex Rest class, you will be able to see them in the dropdown list. Just choose and then put your **BOT TOKEN**, then press "Register".

Here you go, you are now all set! You have a public endpoint welcoming Telegram webhook updates.

> p.s. With regards to possible 'security concerns', here is the thing: Telegram will ping your endpoint with an update appended to your **BOT TOKEN** which, ideally, is only known by you. That way you can 'authenticate' incoming requests in your Rest Controller. (See below example)

```apex
@RestResource(urlMapping='/telegram/*')
global with sharing class TelegramWebhook {
    @HttpPost
    global static void getWebHookUpdate() {
        RestRequest req = RestContext.request;
        if (req.requestURI.substring(req.requestURI.lastIndexOf('/') + 1) != TelegramUtility.TELEGRAM_CHAT_TOKEN) {
            System.debug('Telegram chatbot token is not provided. Can not proceed');
            return;
        }
        TelegramWebhookController.onUpdateReceived(req.requestBody.toString());
    }
}
```
## Setting Up Telegram Bot Token
Set your Telegram Bot Token in Telegram Setup, a custom metadata comes with this package. Do activate the record while creating. (**Setup > Custom Metadata Types > Telegram Setup > Manage Records**)

## Building and Sending Messages with _Connector_

```apex
// send a basic text message synchronously (pass false as a second param for async)
new TelegramMessage.Text('<chat message>').get().sendMessage('<chatId>', true);
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
    .sendMessage('<chatId>', true);

// send a text message with ReplyKeyboard entities for user to react/navigate (flow-based interections, etc.)
Telegram.ReplyKeyboard replyKeyboard1 = new Telegram.ReplyKeyboard();
replyKeyboard1.text = 'Open a Case';
Telegram.ReplyKeyboard replyKeyboard2 = new Telegram.ReplyKeyboard();
replyKeyboard2.text = 'Get My Order Status';
new TelegramMessage.Text('Choose a Salesforce action')
    .addReplyKeyboard(new List<Telegram.ReplyKeyboard>{ replyKeyboard1, replyKeyboard2 }, true, true)
    .get()
    .sendMessage('<chatId>', true);
```
------
Sometimes you might need to force the user to reply to one of your specific messages. So, take this!
```apex
// force user to reply specifically to what your bot is sending out in the chat.
new TelegramMessage.Text('Your response will be linked to this')
    .forceReply()
    .get()
    .sendMessage('<chatId>', true);
```
----
Other than text messages, there are a couple of more options to be used with the _Connector_
```apex
// send a Photo
new TelegramMessage.Photo('photoUrlOrFileId', 'photoCaption').get().sendMessage('<chatId>', true);

// send a Sticker
new TelegramMessage.Sticker('stickerUrlOrFileId').get().sendMessage('<chatId>', true);

// send a Location
new TelegramMessage.Location(12.45654, 20.53214).get().sendMessage('<chatId>', true);

// send a Contact info
new TelegramMessage.Contact('phonoNumber', 'fName', 'lName').get().sendMessage('<chatId>', true);
```
-------
One cool thing with the **ChatAction** class is that it gives your bot the ability to act more "_humanly_" by sending action status before the actual message is sent off.
```apex
// options are: 'typing','upload_photo','record_video','upload_video','record_audio','upload_audio','upload_document','find_location'
new TelegramMessage.ChatAction('typing').get().sendMessage('<chatId>', true);
```

## Parsing Telegram Updates with _Connector_
You can leverage **TelegramMessageParser** class in order to parse the payload coming from Telegram webhook service.
Basically, pass that payload through the constructor and call **_parse()_** method to wrap up the things in a single entity.
```apex
String webhookPayload; // sent off by Telegram
TelegramMessageParser parser = new TelegramMessageParser(webhookPayload).parse();
```

Your **_parser_** instance now holds all the things with which you will need to handle your bot's user interections.
For instance, to grab who is writing to your bot, get _sender_ information as follows.
```apex
// holds sender information
Telegram.TelegramUser sender = parser.getSender();
String chatId = sender.id;
String fName = sender.first_name;
String lName = sender.last_name;
String username = sender.username;
Boolean isBotUser = sender.is_bot;
```

Moreover, you will have the chance to identify which type of incoming message your bot will be coping with.
This is especially crucial and handy when it comes to conducting quiz or flow-based user interections.
```apex
// DETERMINE THE TYPE OF MESSAGE
if (parser.isCallback()) {
    // incoming response is stemmed from CallbackQuery.
    String callbackAction = parser.getMessage();
}

if (parser.isInline()) {
    // incoming response is stemmed from InlineQuery.
    String inlineQuery = parser.getMessage();
}

if (parser.isText()) {
    // incoming message is text
    String text = parser.getMessage();
}

if (parser.isAudio()) {
    // incoming message is audio.
    Object audio = parser.getEntity();
}

if (parser.isPhoto()) {
    // incoming message is photo.
    Object photo = parser.getEntity();
}

if (parser.isSticker()) {
    // incoming message is sticker.
    Object sticker = parser.getEntity();
}

if (parser.isVoice()) {
    // incoming message is voice.
    Object voice = parser.getEntity();
}
```
