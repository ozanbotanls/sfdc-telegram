public with sharing class TelegramSetupController {
    /**
     * Tolerates both quote styles and surrounding whitespace, unlike the previous
     * substringBetween('urlMapping=\'/', '\')') which only matched one exact spelling.
     */
    private static final Pattern URL_MAPPING_PATTERN = Pattern.compile(
        '(?i)urlMapping\\s*=\\s*[\'"]\\s*/?([^\'"]+?)\\s*[\'"]'
    );
    /** Guards heap: class bodies are large and an org can hold thousands of them. */
    private static final Integer MAX_CLASSES_SCANNED = 5000;

    @AuraEnabled(cacheable=true)
    public static List<RestClassWrapper> getRestApexClasses() {
        if (!Schema.SObjectType.ApexClass.isAccessible()) {
            throw auraError('You need the "Author Apex" permission to list Apex REST classes.');
        }
        List<RestClassWrapper> restClasses = new List<RestClassWrapper>();
        // SOQL for-loop so bodies are chunked rather than materialised all at once,
        // and NamespacePrefix = null so managed package source is never pulled into heap
        for (ApexClass cls : [
            SELECT Name, Body
            FROM ApexClass
            WHERE NamespacePrefix = NULL AND Status = 'Active'
            LIMIT :MAX_CLASSES_SCANNED
        ]) {
            if (cls.Body == null || !cls.Body.containsIgnoreCase('@RestResource')) {
                continue;
            }
            Matcher m = URL_MAPPING_PATTERN.matcher(cls.Body);
            if (m.find()) {
                restClasses.add(new RestClassWrapper(cls.Name, m.group(1)));
            }
        }
        return restClasses;
    }

    public class RestClassWrapper {
        @AuraEnabled
        public String name;
        @AuraEnabled
        public String urlMapping;
        public RestClassWrapper(String name, String urlMapping) {
            this.name = name;
            this.urlMapping = urlMapping;
        }
    }

    /**
     * Real host names for the org's active sites.
     *
     * The previous implementation hand-assembled `*.force.com` from
     * Organization.InstanceName and a username suffix. That has been wrong since
     * Enhanced Domains became mandatory -- sandbox sites are now served from
     * `*.sandbox.my.salesforce-sites.com`. DomainSite holds the actual host.
     */
    @AuraEnabled(cacheable=true)
    public static List<String> getSiteUrl() {
        List<String> siteUrls = new List<String>();
        for (DomainSite ds : [
            SELECT PathPrefix, Domain.Domain
            FROM DomainSite
            WHERE Site.Status = 'Active' AND Domain.Domain != NULL
        ]) {
            String siteUrl = 'https://' + ds.Domain.Domain;
            if (String.isNotBlank(ds.PathPrefix)) {
                siteUrl += ds.PathPrefix.startsWith('/') ? ds.PathPrefix : '/' + ds.PathPrefix;
            }
            siteUrls.add(siteUrl);
        }
        return siteUrls;
    }

    /**
     * Registers the webhook with Telegram.
     *
     * The bot token is no longer handed to the browser, so this runs server-side
     * through the Telegram_Bot_API Named Credential. A fresh secret is persisted
     * to the Telegram Setup record FIRST; only once that deployment succeeds is
     * Telegram told about the URL, so there is no window in which Telegram holds
     * a secret the org cannot verify.
     *
     * @return a message describing what was submitted.
     */
    @AuraEnabled
    public static String registerWebhook(String siteUrl, String urlMapping) {
        if (String.isBlank(siteUrl) || String.isBlank(urlMapping)) {
            throw auraError('Choose both a site and an Apex REST class.');
        }
        Telegram_Setup__mdt setup = getActiveSetup();
        if (setup == null) {
            throw auraError(
                'No active Telegram Setup record found. Create one under Custom Metadata Types and tick Is Active.'
            );
        }
        String webhookUrl = buildWebhookUrl(siteUrl, urlMapping);
        String secret = generateSecret();

        if (Test.isRunningTest()) {
            // Metadata deployments cannot be enqueued from a test context
            return 'Registration submitted for ' + webhookUrl;
        }
        Metadata.CustomMetadata record = new Metadata.CustomMetadata();
        record.fullName = 'Telegram_Setup__mdt.' + setup.DeveloperName;
        record.label = setup.MasterLabel;
        record.values = new List<Metadata.CustomMetadataValue>();
        // a custom metadata deployment replaces the record, so restate the fields we are not changing
        record.values.add(customMetadataValue('Webhook_Secret__c', secret));
        record.values.add(customMetadataValue('Is_Active__c', setup.Is_Active__c));
        record.values.add(customMetadataValue('Handler_Class__c', setup.Handler_Class__c));

        Metadata.DeployContainer container = new Metadata.DeployContainer();
        container.addMetadata(record);
        Metadata.Operations.enqueueDeployment(container, new WebhookSecretCallback(webhookUrl, secret));
        return 'Registration submitted for ' + webhookUrl + '. It completes in the background.';
    }

    /**
     * Calls setWebhook only after the secret is safely stored. Queued rather than
     * called inline because a metadata deploy callback is not a callout context.
     */
    public class WebhookSecretCallback implements Metadata.DeployCallback {
        private final String webhookUrl;
        private final String secret;
        public WebhookSecretCallback(String webhookUrl, String secret) {
            this.webhookUrl = webhookUrl;
            this.secret = secret;
        }
        public void handleResult(Metadata.DeployResult result, Metadata.DeployCallbackContext context) {
            if (result == null || result.status != Metadata.DeployStatus.Succeeded) {
                System.debug(LoggingLevel.ERROR, 'Telegram webhook secret was not saved; setWebhook skipped.');
                return;
            }
            String payload = JSON.serialize(
                new Map<String, Object>{
                    'url' => this.webhookUrl,
                    'secret_token' => this.secret,
                    'drop_pending_updates' => true
                }
            );
            System.enqueueJob(new TelegramCalloutQueueable(payload, 'setWebhook'));
        }
    }

    private static Metadata.CustomMetadataValue customMetadataValue(String field, Object value) {
        Metadata.CustomMetadataValue entry = new Metadata.CustomMetadataValue();
        entry.field = field;
        entry.value = value;
        return entry;
    }

    /** AuraHandledException drops its message unless setMessage is called too. */
    private static AuraHandledException auraError(String message) {
        AuraHandledException e = new AuraHandledException(message);
        e.setMessage(message);
        return e;
    }

    @TestVisible
    private static String buildWebhookUrl(String siteUrl, String urlMapping) {
        String mapping = urlMapping.trim();
        if (mapping.endsWith('/*')) {
            mapping = mapping.removeEnd('/*');
        }
        return siteUrl.removeEnd('/') + '/services/apexrest/' + mapping.removeStart('/');
    }

    /** 256 bits of randomness, restricted to the characters Telegram allows in secret_token. */
    @TestVisible
    private static String generateSecret() {
        return EncodingUtil.convertToHex(Crypto.generateAesKey(256));
    }

    @TestVisible
    private static Telegram_Setup__mdt getActiveSetup() {
        for (Telegram_Setup__mdt setup : Telegram_Setup__mdt.getAll().values()) {
            if (setup.Is_Active__c == true) {
                return setup;
            }
        }
        return null;
    }
}
