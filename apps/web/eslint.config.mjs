import baseConfig from "@xingye/config-eslint/base.mjs";

/** @type {import('eslint').Linter.Config[]} */
export default [
  ...baseConfig,
  {
    ignores: [".next/**", "node_modules/**"],
  },
];
