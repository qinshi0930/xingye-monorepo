// ESLint 9 flat config - 直接导入 next 配置避免 FlatCompat 循环引用
import js from "@eslint/js";
import ts from "typescript-eslint";
import react from "eslint-plugin-react";
import hooks from "eslint-plugin-react-hooks";
import nextCore from "@next/eslint-plugin-next";
import globals from "globals";

/** @type {import('eslint').Linter.Config[]} */
const config = [
  js.configs.recommended,
  ...ts.configs.recommended,
  {
    plugins: {
      react: react,
      "react-hooks": hooks,
      "@next/next": nextCore,
    },
    languageOptions: {
      globals: {
        ...globals.browser,
        ...globals.node,
        ...globals.es2021,
      },
    },
    rules: {
      // React rules
      "react/react-in-jsx-scope": "off",
      "react/prop-types": "off",
      
      // React Hooks rules
      "react-hooks/rules-of-hooks": "error",
      "react-hooks/exhaustive-deps": "warn",
      
      // Next.js rules
      "@next/next/no-html-link-for-pages": "off",
      
      // TypeScript rules
      "@typescript-eslint/no-unused-vars": [
        "error",
        {
          argsIgnorePattern: "^_",
          varsIgnorePattern: "^_",
        },
      ],
      "@typescript-eslint/no-require-imports": "off",
    },
    settings: {
      react: {
        version: "detect",
      },
    },
  },
  // Jest 配置文件特殊处理
  {
    files: ["**/jest.setup.js", "**/jest.config.*", "**/__tests__/**/*"],
    languageOptions: {
      globals: {
        ...globals.jest,
        ...globals.node,
      },
    },
  },
  {
    ignores: [".next/**", "node_modules/**", "dist/**", "*.config.*"],
  },
];

export default config;
