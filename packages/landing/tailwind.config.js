/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      animation: {
        'slow-pan': 'slowPan 60s ease-in-out infinite alternate',
      },
      keyframes: {
        slowPan: {
          '0%': { transform: 'translate(0, 0) scale(1.1)' },
          '100%': { transform: 'translate(-5%, -5%) scale(1.15)' },
        },
      },
    },
  },
  plugins: [],
};
