import { LightningElement, track } from "lwc";
import { showSuccessMessage, showErrorMessage } from "c/showMessageHelper";

export default class TelegramSetup extends LightningElement {
    @track siteUrl;
    @track botToken;

    handleSiteUrl(event) {
        this.siteUrl = event.target.value;
    }
    handleBotToken(event) {
        this.botToken = event.target.value;
    }
    get disabled() {
        return !this.siteUrl || !this.botToken;
    }
    handleRegister() {
        fetch(
            "https://api.telegram.org/bot" +
                this.botToken +
                "/setWebhook?url=" +
                this.siteUrl +
                "/services/apexrest/telegram/" +
                this.botToken,
            {
                method: "POST",
                headers: { "Content-Type": "application/json" }
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
