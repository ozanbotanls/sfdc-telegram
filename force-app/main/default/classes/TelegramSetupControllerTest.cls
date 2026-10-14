@IsTest
private class TelegramSetupControllerTest {
    @IsTest
    static void findsRestResourcesAndTheirUrlMapping() {
        Test.startTest();
        List<TelegramSetupController.RestClassWrapper> classes = TelegramSetupController.getRestApexClasses();
        Test.stopTest();

        Map<String, String> mappingByName = new Map<String, String>();
        for (TelegramSetupController.RestClassWrapper wrapper : classes) {
            mappingByName.put(wrapper.name, wrapper.urlMapping);
        }

        Assert.isTrue(mappingByName.containsKey('TelegramWebhook'), 'the shipped REST resource should be listed');
        Assert.areEqual('telegram/*', mappingByName.get('TelegramWebhook'));
    }

    @IsTest
    static void siteUrlsAreDerivedFromRealHostNames() {
        Test.startTest();
        List<String> urls = TelegramSetupController.getSiteUrl();
        Test.stopTest();

        // a scratch org usually has no active site; assert the shape of whatever is returned
        for (String url : urls) {
            Assert.isTrue(url.startsWith('https://'), 'sites are HTTPS only');
            Assert.isFalse(url.contains('null'), 'no hand-assembled host fragments');
        }
    }

    @IsTest
    static void buildsTheWebhookUrlFromSiteAndMapping() {
        Assert.areEqual(
            'https://example.my.salesforce-sites.com/bot/services/apexrest/telegram',
            TelegramSetupController.buildWebhookUrl('https://example.my.salesforce-sites.com/bot/', '/telegram/*')
        );
        Assert.areEqual(
            'https://example.my.salesforce-sites.com/services/apexrest/telegram',
            TelegramSetupController.buildWebhookUrl('https://example.my.salesforce-sites.com', 'telegram')
        );
    }

    @IsTest
    static void generatedSecretsAreLongAndUnique() {
        String first = TelegramSetupController.generateSecret();
        String second = TelegramSetupController.generateSecret();

        Assert.areEqual(64, first.length(), '256 bits as hex');
        Assert.areNotEqual(first, second);
        Assert.isTrue(Pattern.matches('[0-9a-fA-F]{64}', first), 'Telegram restricts secret_token characters');
    }

    @IsTest
    static void registerWebhookRequiresBothInputs() {
        TelegramSetupController.setupOverridden = true;
        TelegramSetupController.setupOverride = new Telegram_Setup__mdt(Is_Active__c = true);
        try {
            TelegramSetupController.registerWebhook(null, '/telegram/*');
            Assert.fail('a missing site should be rejected');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().containsIgnoreCase('site'));
        }
    }

    @IsTest
    static void registerWebhookRequiresAnActiveSetupRecord() {
        TelegramSetupController.setupOverridden = true;
        TelegramSetupController.setupOverride = null;
        try {
            TelegramSetupController.registerWebhook('https://example.com', '/telegram/*');
            Assert.fail('registration without an active setup record should be rejected');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().containsIgnoreCase('active'));
        }
    }

    @IsTest
    static void registerWebhookAcceptsValidInput() {
        TelegramSetupController.setupOverridden = true;
        TelegramSetupController.setupOverride = new Telegram_Setup__mdt(Is_Active__c = true);

        Test.startTest();
        String message = TelegramSetupController.registerWebhook('https://example.com', '/telegram/*');
        Test.stopTest();

        Assert.isTrue(message.contains('/services/apexrest/telegram'), 'should report the registered URL');
    }

    @IsTest
    static void deployCallbackQueuesSetWebhookOnlyOnSuccess() {
        TelegramCalloutMock mock = new TelegramCalloutMock();
        Test.setMock(HttpCalloutMock.class, mock);
        TelegramSetupController.WebhookSecretCallback callback = new TelegramSetupController.WebhookSecretCallback(
            'https://example.com/services/apexrest/telegram',
            'a-secret'
        );

        Test.startTest();
        callback.handleResult(null, null); // a failed deployment must not register anything
        Test.stopTest();

        Assert.areEqual(0, mock.callCount, 'Telegram must not learn a secret the org failed to store');
    }
}
