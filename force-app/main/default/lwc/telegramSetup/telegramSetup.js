import { LightningElement, wire } from "lwc";
import { showSuccessMessage, showErrorMessage } from "c/showMessageHelper";
import getRestApexClasses from "@salesforce/apex/TelegramSetupController.getRestApexClasses";
import getSiteUrl from "@salesforce/apex/TelegramSetupController.getSiteUrl";
import registerWebhook from "@salesforce/apex/TelegramSetupController.registerWebhook";

export default class TelegramSetup extends LightningElement {
    siteUrls = [];
    restClasses = [];
    chosenSite;
    chosenClass;
    registering = false;

    @wire(getRestApexClasses)
    getRestClasses({ error, data }) {
        if (data) {
            this.restClasses = data.map(cls => ({ value: cls.urlMapping, label: cls.name }));
        } else if (error) {
            showErrorMessage("Could not load Apex REST classes", this.reduceError(error));
        }
    }

    @wire(getSiteUrl)
    getSites({ error, data }) {
        if (data) {
            this.siteUrls = data.map(url => ({ value: url, label: url }));
        } else if (error) {
            showErrorMessage("Could not load sites", this.reduceError(error));
        }
    }

    get classes() {
        return this.restClasses;
    }

    get sites() {
        return this.siteUrls;
    }

    handleSiteChange(event) {
        this.chosenSite = event.detail.value;
    }

    handleClassChange(event) {
        this.chosenClass = event.detail.value;
    }

    get disabled() {
        return !this.chosenSite || !this.chosenClass || this.registering;
    }

    /**
     * The bot token lives in the Telegram_Bot_API Named Credential, so registration
     * happens in Apex. Nothing secret passes through the browser.
     */
    handleRegister() {
        this.registering = true;
        registerWebhook({ siteUrl: this.chosenSite, urlMapping: this.chosenClass })
            .then(message => {
                showSuccessMessage("Registered!", message);
            })
            .catch(error => {
                showErrorMessage("Registration failed", this.reduceError(error));
            })
            .finally(() => {
                this.registering = false;
            });
    }

    reduceError(error) {
        return (
            error?.body?.message ||
            error?.body?.pageErrors?.[0]?.message ||
            error?.message ||
            "An unexpected error occurred."
        );
    }
}
