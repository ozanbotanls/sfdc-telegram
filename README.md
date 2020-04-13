Fundementals of "SFDC - Telegram Basic Integration"

You can leverage TelegramMessageParser class in order to parse the payload coming from Telegram webhook service.
Basically, pass that payload into the constructor and call parse() method to wrap up the things in a single entity.
```apex
String webhookPayload; // sent off by Telegram
TelegramMessageParser parser = new TelegramMessageParser(webhookPayload).parse();
```

Your "parser" instance now holds all the things that you will need to handle your bot's user interections.
For instance, to grab who is writing to your bot, get sender information as follows.
```apex
// holds sender information
Telegram.TelegramUser sender = parser.getSender();
String chatId = sender.id;
String fName = sender.first_name;
String lName = sender.last_name;
String username = sender.username;
Boolean isBotUser = sender.is_bot;
```

Moreover, you will have the chance to identify which type of incoming message your bot will be tackling with.
This is especially important when it comes to conduct quiz or flow-based user interections.
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
