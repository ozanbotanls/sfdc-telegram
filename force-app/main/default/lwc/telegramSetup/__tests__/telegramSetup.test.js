import { createElement } from "lwc";
import TelegramSetup from "c/telegramSetup";
import getRestApexClasses from "@salesforce/apex/TelegramSetupController.getRestApexClasses";
import getSiteUrl from "@salesforce/apex/TelegramSetupController.getSiteUrl";
import registerWebhook from "@salesforce/apex/TelegramSetupController.registerWebhook";

// @wire-ed Apex methods need a test wire adapter; the imperative one is a plain mock.
jest.mock(
    "@salesforce/apex/TelegramSetupController.getRestApexClasses",
    () => {
        const { createApexTestWireAdapter } = require("@salesforce/wire-service-jest-util");
        return { default: createApexTestWireAdapter(jest.fn()) };
    },
    { virtual: true }
);
jest.mock(
    "@salesforce/apex/TelegramSetupController.getSiteUrl",
    () => {
        const { createApexTestWireAdapter } = require("@salesforce/wire-service-jest-util");
        return { default: createApexTestWireAdapter(jest.fn()) };
    },
    { virtual: true }
);
jest.mock("@salesforce/apex/TelegramSetupController.registerWebhook", () => ({ default: jest.fn() }), {
    virtual: true
});

const SITES = ["https://example.my.salesforce-sites.com/bot"];
const CLASSES = [{ name: "TelegramWebhook", urlMapping: "telegram/*" }];

describe("c-telegram-setup", () => {
    let element;

    beforeEach(() => {
        element = createElement("c-telegram-setup", { is: TelegramSetup });
        document.body.appendChild(element);
    });

    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    const flush = () => Promise.resolve();
    const comboboxes = () => Array.from(element.shadowRoot.querySelectorAll("lightning-combobox"));
    const button = () => element.shadowRoot.querySelector("lightning-button");
    const select = async (combobox, value) => {
        combobox.dispatchEvent(new CustomEvent("change", { detail: { value } }));
        await flush();
    };

    /** Regression: the bot token used to be typed into this form and sent to the browser. */
    it("never asks for the bot token", () => {
        expect(element.shadowRoot.querySelector("lightning-input")).toBeNull();
    });

    it("lists the sites and REST classes returned by Apex", async () => {
        getSiteUrl.emit(SITES);
        getRestApexClasses.emit(CLASSES);
        await flush();

        const [sites, classes] = comboboxes();
        expect(sites.options).toEqual([{ value: SITES[0], label: SITES[0] }]);
        expect(classes.options).toEqual([{ value: "telegram/*", label: "TelegramWebhook" }]);
    });

    it("keeps Register disabled until a site and a class are chosen", async () => {
        getSiteUrl.emit(SITES);
        getRestApexClasses.emit(CLASSES);
        await flush();
        expect(button().disabled).toBe(true);

        const [sites, classes] = comboboxes();
        await select(sites, SITES[0]);
        expect(button().disabled).toBe(true);

        await select(classes, "telegram/*");
        expect(button().disabled).toBe(false);
    });

    it("registers the webhook through Apex, not through the browser", async () => {
        registerWebhook.mockResolvedValue("Registration submitted for https://example.com");
        getSiteUrl.emit(SITES);
        getRestApexClasses.emit(CLASSES);
        await flush();

        const [sites, classes] = comboboxes();
        await select(sites, SITES[0]);
        await select(classes, "telegram/*");
        button().click();
        await flush();

        expect(registerWebhook).toHaveBeenCalledWith({
            siteUrl: SITES[0],
            urlMapping: "telegram/*"
        });
    });

    it("surfaces a registration failure instead of swallowing it", async () => {
        registerWebhook.mockRejectedValue({ body: { message: "No active Telegram Setup record found." } });
        const toast = jest.fn();
        element.addEventListener("lightning__showtoast", toast);

        getSiteUrl.emit(SITES);
        getRestApexClasses.emit(CLASSES);
        await flush();
        const [sites, classes] = comboboxes();
        await select(sites, SITES[0]);
        await select(classes, "telegram/*");
        button().click();
        await flush();
        await flush();

        expect(toast).toHaveBeenCalled();
        expect(toast.mock.calls[0][0].detail.variant).toBe("error");
        expect(toast.mock.calls[0][0].detail.message).toBe("No active Telegram Setup record found.");
    });
});
