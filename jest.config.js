const { jestConfig } = require("@salesforce/sfdx-lwc-jest/config");

module.exports = {
    ...jestConfig,
    moduleNameMapper: {
        "^lightning/platformShowToastEvent$": "<rootDir>/jest-mocks/lightning/platformShowToastEvent"
    }
};
