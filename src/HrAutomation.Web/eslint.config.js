import js from "@eslint/js";
import globals from "globals";
import reactHooks from "eslint-plugin-react-hooks";
import reactRefresh from "eslint-plugin-react-refresh";
import jsxA11y from "eslint-plugin-jsx-a11y";
import tseslint from "typescript-eslint";

export default tseslint.config(
  {
    ignores: [
      "dist",
      "coverage",
      "playwright-report",
      "src/api/generated",
      "node_modules",
      "public",
    ],
  },
  {
    extends: [js.configs.recommended, ...tseslint.configs.recommended],
    files: ["**/*.{ts,tsx}"],
    languageOptions: {
      ecmaVersion: 2022,
      globals: globals.browser,
    },
    plugins: {
      "react-hooks": reactHooks,
      "react-refresh": reactRefresh,
      "jsx-a11y": jsxA11y,
    },
    rules: {
      ...reactHooks.configs.recommended.rules,
      ...jsxA11y.configs.recommended.rules,
      "react-refresh/only-export-components": ["warn", { allowConstantExport: true }],
      "@typescript-eslint/no-unused-vars": [
        "error",
        { argsIgnorePattern: "^_", varsIgnorePattern: "^_" },
      ],
      "@typescript-eslint/consistent-type-imports": "error",
      "no-console": ["error", { allow: ["warn", "error"] }],
      // Blocks both bare `localStorage`/`sessionStorage` AND `window.localStorage`/
      // `window.sessionStorage` — no-restricted-globals alone only catches the
      // unqualified form, so a `window.` prefix would silently bypass it.
      "no-restricted-globals": ["error", "localStorage", "sessionStorage"],
      "no-restricted-properties": [
        "error",
        {
          object: "window",
          property: "localStorage",
          message: "See docs/05-security-governance/frontend-security.md — browser storage is restricted.",
        },
        {
          object: "window",
          property: "sessionStorage",
          message: "See docs/05-security-governance/frontend-security.md — browser storage is restricted.",
        },
      ],
      "no-restricted-syntax": [
        "error",
        {
          selector: "CallExpression[callee.name='dangerouslySetInnerHTML']",
          message: "Do not use dangerouslySetInnerHTML directly. Sanitize via lib/sanitize.ts.",
        },
      ],
    },
  },
  {
    // The ONLY sanctioned browser-storage usage: a non-sensitive UI preference
    // (light/dark theme). Any other file needing storage access must be added
    // here deliberately, with a docs/05-security-governance/frontend-security.md
    // update and a security review — never silently.
    files: ["src/app/providers/ThemeProvider.tsx"],
    rules: {
      "no-restricted-globals": "off",
      "no-restricted-properties": "off",
    },
  },
  {
    files: ["**/*.test.{ts,tsx}", "src/tests/**", "src/mocks/**", "e2e/**"],
    rules: {
      "@typescript-eslint/no-explicit-any": "off",
    },
  },
  {
    // Vitest's own documented pattern for merging `test` config into Vite's
    // UserConfig type requires this exact triple-slash reference.
    files: ["vite.config.ts"],
    rules: {
      "@typescript-eslint/triple-slash-reference": "off",
    },
  }
);
