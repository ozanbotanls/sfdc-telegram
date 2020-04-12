import { ShowToastEvent } from "lightning/platformShowToastEvent";

const showSuccessMessage = (title, message) => {
    dispatchEvent(
        new ShowToastEvent({
            title: title,
            message: message,
            variant: "success"
        })
    );
};

const showErrorMessage = (title, message) => {
    dispatchEvent(
        new ShowToastEvent({
            title: title,
            message: message,
            variant: "error"
        })
    );
};

const showMessage = (type = "success", title, message) => {
    dispatchEvent(
        new ShowToastEvent({
            title: title,
            message: message,
            variant: type
        })
    );
};

export { showSuccessMessage, showErrorMessage, showMessage };
