public with sharing class TelegramSetupController {
    @AuraEnabled(cacheable=true)
    public static List<String> getSiteUrl() {
        List<Site> siteList = [
            SELECT GuestUserId, Name, MasterLabel, Subdomain, OptionsRequireHttps, UrlPathPrefix
            FROM Site
            WHERE Status = 'Active'
            LIMIT 100
        ];
        List<String> siteFullUrlList = new List<String>();
        /** We can get instance of the org from organisation object **/
        Organization org = [
            SELECT InstanceName, Name, IsSandbox, OrganizationType, TrialExpirationDate
            FROM Organization
        ];
        if (siteList != null && siteList.size() != 0) {
            for (Site s : siteList) {
                if (s.Subdomain != null) {
                    String httpStr = 'http://';
                    if (s.OptionsRequireHttps == true) {
                        httpStr = 'https://';
                    }
                    String siteFullUrl = httpStr;
                    // scratch org
                    if (org.IsSandbox && org.TrialExpirationDate != null) {
                        siteFullUrl += 'sandbox-';
                    }
                    // sandbox
                    if (org.IsSandbox == true && org.TrialExpirationDate == null) {
                        siteFullUrl += UserInfo.getUserName().substringAfterLast('.') + '-';
                    }
                    siteFullUrl += s.Subdomain + '.';
                    siteFullUrl +=
                        (org.IsSandbox || org.OrganizationType == 'Developer Edition'
                            ? (org.InstanceName.toLowerCase() + '.')
                            : '') + 'force.com';
                    if (s.UrlPathPrefix != null) {
                        siteFullUrl += '/' + s.UrlPathPrefix;
                    }
                    siteFullUrlList.add(siteFullUrl);
                }
            }
        }
        return siteFullUrlList;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, String> getRestApexClasses() {
        Map<String, String> restClasses = new Map<String, String>();
        for (ApexClass cls : [SELECT Id, Name, Body FROM ApexClass WHERE Name != 'TelegramSetupController']) {
            if (cls.body.containsIgnoreCase('@RestResource') && cls.body.containsIgnoreCase('urlMapping=')) {
                String urlMapping = cls.body.substringBetween('urlMapping=', ')');
                restClasses.putAll(new Map<String, String>{ 'key' => cls.Name, 'val' => urlMapping });
            }
        }
        return restClasses;
    }
}