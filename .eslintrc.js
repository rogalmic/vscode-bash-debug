module.exports = {
    parser: "@typescript-eslint/parser",
    parserOptions: {
        ecmaVersion: 2020,
        sourceType: "module" // Allows for the use of imports
    },
    extends: [
        "plugin:@typescript-eslint/recommended" // Uses the recommended rules from the @typescript-eslint/eslint-plugin
    ],
    rules: {
        "@typescript-eslint/ban-types": "off",
        "@typescript-eslint/no-unused-vars": "off"
    }
};