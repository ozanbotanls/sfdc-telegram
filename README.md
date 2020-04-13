## Fundamentals of _Telegram Connector for Salesforce_
---------

This codebase will allow Salesforce Developers to easily integrate the Salesforce platform with Telegram through Bot API. This is not complete coverage, but fair enough to get you going by eliminating a lot of hassles with which, under normal circumstances, developers would have been facing in overcoming basic communication.

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
