public with sharing class TelegramSetupController {
    @AuraEnabled(cacheable=true)
    public static List<RestClassWrapper> getRestApexClasses() {
        List<RestClassWrapper> restClasses = new List<RestClassWrapper>();
        for (ApexClass cls : [SELECT Id, Name, Body FROM ApexClass WHERE Name != 'TelegramSetupController']) {
            if (cls.body.containsIgnoreCase('@RestResource') && cls.body.containsIgnoreCase('urlMapping=')) {
                String urlMapping = cls.body.substringBetween('urlMapping=\'/', '\')');
                restClasses.add(new RestClassWrapper(cls.Name, urlMapping));
            }
        }
        return restClasses;
    }

    class RestClassWrapper {
        @AuraEnabled
        public String name;
        @AuraEnabled
        public String urlMapping;
        public RestClassWrapper(String name, String urlMapping) {
            this.name = name;
            this.urlMapping = urlMapping;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getSiteUrl() {
        List<Site> siteList = [
            SELECT Subdomain, OptionsRequireHttps, UrlPathPrefix
            FROM Site
            WHERE Status = 'Active' AND Subdomain != null
        ];
        List<String> siteUrls = new List<String>();
        Organization org = [
            SELECT InstanceName, Name, IsSandbox, OrganizationType, TrialExpirationDate
            FROM Organization
        ];
        for (Site s : siteList) {
            String siteUrl = 'http://';
            if (s.OptionsRequireHttps == true) {
                siteUrl = 'https://';
            }
            // either sandbox or scratch org
            if (org.IsSandbox) {
                siteUrl += org.TrialExpirationDate != null
                    ? 'sandbox-'
                    : UserInfo.getUserName().substringAfterLast('.') + '-';
            }
            siteUrl += s.Subdomain + '.';
            siteUrl +=
                (org.IsSandbox || org.OrganizationType == 'Developer Edition'
                    ? (org.InstanceName.toLowerCase() + '.')
                    : '') + 'force.com';
            if (s.UrlPathPrefix != null) {
                siteUrl += '/' + s.UrlPathPrefix;
            }
            siteUrls.add(siteUrl);
        }
        return siteUrls;
    }
}