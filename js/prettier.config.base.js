// tanh-tooling/prettier — shared Prettier base.
//
// Consumer wiring (prettier.config.js):
//   import base from "tanh-tooling/prettier";
//   export default { ...base /* per-repo overrides */ };

/** @type {import("prettier").Config} */
export default {
  semi: true,
  printWidth: 90,
  singleQuote: false,
  arrowParens: "always",
  trailingComma: "none",
  tabWidth: 4,
};
