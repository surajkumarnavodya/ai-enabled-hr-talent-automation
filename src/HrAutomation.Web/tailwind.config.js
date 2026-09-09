/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  darkMode: "class",
  theme: {
    extend: {
      colors: {
        // Neutral, professional palette. Status colors are always paired with an
        // icon/label/text in components — never color alone (see StatusBadge.tsx).
        brand: {
          50: "#f0f5fb",
          100: "#dae7f4",
          500: "#2f6fb0",
          600: "#265a8c",
          700: "#1e4770",
        },
        status: {
          success: "#1a7f4b",
          warning: "#a15c00",
          danger: "#b3261e",
          info: "#2f6fb0",
          neutral: "#5b6470",
        },
      },
    },
  },
  plugins: [],
};
