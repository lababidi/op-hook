"use client";

import { useEffect, useState } from "react";
import { useGetOptions } from "../useGetOptions";

export default function OpSwapFront() {
  const [isDark, setIsDark] = useState(false);

  useEffect(() => {
    console.log("OpSwap page is loading!");
    // Check system preference on mount
    const prefersDark = window.matchMedia("(prefers-color-scheme: dark)").matches;
    setIsDark(prefersDark);
  }, []);
  const { prices } = useGetOptions();

  const toggleTheme = () => {
    setIsDark(!isDark);
  };

  return (
    <div
      className={`min-h-screen transition-colors duration-300 font-light ${
        isDark ? "bg-black text-white" : "bg-white text-black"
      }`}
    >
      <div className="container mx-auto px-4 py-8">
        {/* Header */}
        <header className="flex justify-between items-center mb-12">
          <div className="flex items-center space-x-4">
            {/* Placeholder Logo */}
            <div
              className={`w-12 h-12 rounded-lg flex items-center justify-center ${isDark ? "bg-white" : "bg-black"}`}
            >
              <span className={`font-medium text-xl ${isDark ? "text-black" : "text-white"}`}>OS</span>
            </div>
            <h1 className="text-3xl font-semibold font-geist">OpSwap</h1>
          </div>

          {/* Theme Toggle */}
          <button
            onClick={toggleTheme}
            className={`relative p-3 rounded-full transition-all duration-300 transform hover:scale-105 ${
              isDark
                ? "bg-white hover:bg-gray-100 shadow-lg shadow-white/20"
                : "bg-black hover:bg-gray-800 shadow-lg shadow-black/20"
            }`}
            aria-label="Toggle theme"
          >
            <span className="text-lg">{isDark ? "☀️" : "🌙"}</span>
          </button>
        </header>

        {/* Main Content */}
        <main className="max-w-4xl mx-auto">
          {/* Hero Section */}
          <section className="text-center mb-16">
            <div className="flex justify-center space-x-4">
              {prices && prices.length > 0 ? (
                <div className="grid grid-cols-2 md:grid-cols-4 gap-4 w-full max-w-2xl">
                  {prices.map((price, idx) => (
                    <div
                      key={idx}
                      className={`p-4 rounded-lg border text-center ${
                        isDark ? "bg-gray-900 border-gray-800 text-white" : "bg-gray-100 border-gray-300 text-black"
                      }`}
                    >
                      <div className="text-lg font-semibold">{price.optionToken}</div>
                      <div className="text-2xl font-light mt-2">${price.price}</div>
                    </div>
                  ))}
                </div>
              ) : (
                <div className={isDark ? "text-gray-400" : "text-gray-500"}>Loading prices...</div>
              )}
            </div>
          </section>
        </main>

        {/* Footer */}
        <footer className={`text-center py-8 border-t font-light ${isDark ? "border-gray-800" : "border-gray-200"}`}>
          <p className={isDark ? "text-gray-400" : "text-gray-500"}>© 2024 OpSwap. Built with ❤️ on Ethereum</p>
        </footer>
      </div>
    </div>
  );
}
