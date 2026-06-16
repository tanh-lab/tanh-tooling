// @tanh-lab/tanh-tooling — shared ESLint flat-config base.
//
// Consumer wiring (eslint.config.js):
//   import tanh from "@tanh-lab/tanh-tooling";
//   export default [...tanh, { /* per-repo overrides */ }];
//
// Mirrors the tanh-lab house rules: import sorting, unused-import pruning,
// no `any`, no floating promises, no console, no import cycles, and the
// React Hooks / React Compiler rules. Type-aware rules use the project
// service, so consumers do not need to wire `parserOptions.project`.

import importPlugin from "eslint-plugin-import";
import react from "eslint-plugin-react";
import reactCompiler from "eslint-plugin-react-compiler";
import reactHooks from "eslint-plugin-react-hooks";
import simpleImportSort from "eslint-plugin-simple-import-sort";
import unusedImports from "eslint-plugin-unused-imports";
import tseslint from "typescript-eslint";

export default tseslint.config(
  ...tseslint.configs.recommendedTypeChecked,
  {
    languageOptions: {
      parserOptions: {
        projectService: true,
      },
    },
    plugins: {
      "unused-imports": unusedImports,
      "simple-import-sort": simpleImportSort,
      import: importPlugin,
      react,
      "react-hooks": reactHooks,
      "react-compiler": reactCompiler,
    },
    rules: {
      "@typescript-eslint/no-unused-vars": "off",
      "unused-imports/no-unused-imports": "error",
      "unused-imports/no-unused-vars": [
        "error",
        {
          vars: "all",
          args: "none",
          ignoreRestSiblings: true,
          caughtErrors: "all",
          varsIgnorePattern: "^_",
        },
      ],
      "simple-import-sort/imports": "error",
      "simple-import-sort/exports": "error",
      "@typescript-eslint/no-explicit-any": "error",
      "@typescript-eslint/no-floating-promises": "error",
      "no-console": "error",
      "import/no-cycle": "error",
      "react-hooks/exhaustive-deps": "error",
      "react-compiler/react-compiler": "error",
      "react/no-array-index-key": "error",
      "react/display-name": "off",
      "@typescript-eslint/array-type": "off",
    },
  },
);
