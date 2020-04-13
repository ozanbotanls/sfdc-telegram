## _Telegram Connector for Salesforce_
---------

This codebase will allow Salesforce Developers to easily integrate the Salesforce platform with Telegram through Bot API. This is not complete coverage, but fair enough to get developers going by eliminating a lot of hassles with which, under normal circumstances, they might have been facing in overcoming basic communication between two systems.

### Building and Sending Messages with _Connector_

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
Sometimes you might need to force the user to reply to one your specific messages. So, take this!
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
One cool thing is with the **ChatAction** class is that it gives your bot the ability to act more "_humanly_" by sending action status before the actual message is sent off.
```apex
// options are: 'typing','upload_photo','record_video','upload_video','record_audio','upload_audio','upload_document','find_location'
new TelegramMessage.ChatAction('typing').get().sendMessage('<chatId>', true);
```

### Parsing Telegram Updates with _Connector_
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
