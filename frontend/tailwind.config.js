/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ['./src/renderer/**/*.{html,tsx,ts}'],
  theme: {
    extend: {
      colors: {
        'booth-pink': '#f0648c',
        'booth-dark': '#1a1a2e',
      },
      fontFamily: {
        sans: [
          'Hiragino Kaku Gothic ProN',
          'Hiragino Sans',
          'Meiryo',
          'Yu Gothic',
          'system-ui',
          'sans-serif',
        ],
      },
    },
  },
  plugins: [],
};
