import { ShowToastEvent } from "lightning/platformShowToastEvent";

/**
 * ShowToastEvent only reaches Lightning Experience when it is dispatched from a
 * component in the DOM. These helpers previously called the module-scoped
 * dispatchEvent, which fires on `window`, so no toast was ever displayed --
 * pass the calling component (`this`) as the first argument.
 */
const dispatchToast = (component, variant, title, message) => {
    component.dispatchEvent(
        new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        })
    );
};

const showSuccessMessage = (component, title, message) => dispatchToast(component, "success", title, message);

const showErrorMessage = (component, title, message) => dispatchToast(component, "error", title, message);

const showMessage = (component, title, message, variant = "success") =>
    dispatchToast(component, variant, title, message);

export { showSuccessMessage, showErrorMessage, showMessage };
