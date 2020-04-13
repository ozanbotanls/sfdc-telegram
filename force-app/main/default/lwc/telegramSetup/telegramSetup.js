import { LightningElement, wire } from "lwc";
import { showSuccessMessage, showErrorMessage } from "c/showMessageHelper";
import getRestApexClasses from "@salesforce/apex/TelegramSetupController.getRestApexClasses";
import getSiteUrl from "@salesforce/apex/TelegramSetupController.getSiteUrl";

export default class TelegramSetup extends LightningElement {
    siteUrls = [];
    restClasses = [];
    chosenSite;
    chosenClass;
    botToken;

    @wire(getRestApexClasses)
    getRestClasses({ error, data }) {
        if (data) {
            window.console.log(JSON.stringify(data));
            for (let i = 0; i < data.length; i++) {
                this.restClasses = [...this.restClasses, { value: data[i].key, label: data[i].val }];
            }
        } else if (error) {
            window.console.log("error => " + JSON.stringify(error));
        }
    }
    @wire(getSiteUrl)
    getSites({ error, data }) {
        if (data) {
            for (let i = 0; i < data.length; i++) {
                this.siteUrls = [...this.siteUrls, { value: data[i], label: data[i] }];
            }
        } else if (error) {
            window.console.log("error => " + JSON.stringify(error));
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
    handleBotToken(event) {
        this.botToken = event.target.value;
    }
    get disabled() {
        return !this.chosenSite || !this.chosenClass || !this.botToken;
    }
    handleRegister() {
        fetch(
            "https://api.telegram.org/bot" +
                this.botToken +
                "/setWebhook?url=" +
                this.chosenSite +
                "/services/apexrest/" +
                this.chosenClass +
                "/" +
                this.botToken,
            {
                method: "POST",
                headers: {
                    "Content-Type": "application/json"
                }
            }
        )
            .then(response => {
                return response.json();
            })
            .then(jsonResponse => {
                window.console.log("jsonResponse ===> " + JSON.stringify(jsonResponse));
                showSuccessMessage("Registered!", "You have subscribed to Telegram webhook service succesfully");
            })
            .catch(error => {
                window.console.log("callout error ===> " + JSON.stringify(error));
                showErrorMessage("Error Occurred!", "Registration attempt to Telegram webhook service failed!");
            });
    }
}
