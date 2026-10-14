/**
 * Stub for lightning/platformShowToastEvent, which is not part of the
 * lwc-jest stub set. Mirrors the real event's shape closely enough to assert on.
 */
export const ShowToastEvent = class extends CustomEvent {
    constructor(toast) {
        super("lightning__showtoast", { detail: toast, bubbles: true, composed: true });
    }
};
